package com.vikstudios.artura.services

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import com.vikstudios.artura.data.AppJson
import com.vikstudios.artura.data.Profile
import com.vikstudios.artura.data.RemoteCatalog
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.doubleOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.put
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import java.security.SecureRandom
import java.time.Instant

/**
 * The user's account, with Supabase Auth: Google gives an identity token, Supabase checks it and creates
 * (or finds) the user, and returns a session. The session is kept encrypted on the device.
 * No SDK: a few calls to the Auth and REST APIs (same as iOS).
 */
object SupabaseAuth {
    @Serializable
    data class Session(
        val accessToken: String,
        val refreshToken: String,
        /** Seconds since 1970. */
        val expiresAt: Double,
        val userId: String,
        /** "apple" or "google". */
        val provider: String,
    )

    class Rejected(message: String) : Exception(message)

    private lateinit var prefs: SharedPreferences
    private const val sessionKey = "supabase.session"

    fun init(context: Context) {
        prefs = try {
            val master = MasterKey.Builder(context).setKeyScheme(MasterKey.KeyScheme.AES256_GCM).build()
            EncryptedSharedPreferences.create(context, "artura.secure", master,
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM)
        } catch (_: Exception) {
            context.getSharedPreferences("artura.secure.fallback", Context.MODE_PRIVATE)
        }
    }

    /** Exchanges a Google identity token for a Supabase session. `nonce` is the raw nonce whose SHA-256 was given to Google. */
    suspend fun signIn(provider: String, idToken: String, nonce: String?): Session {
        val body = buildJsonObject {
            put("provider", provider)
            put("id_token", idToken)
            if (nonce != null) put("nonce", nonce)
        }
        val json = post("/auth/v1/token?grant_type=id_token", body, RemoteCatalog.key)
        val session = session(json, provider)
        store(session)
        return session
    }

    /** The saved session, refreshed if it expires within a minute. Null when signed out or when it cannot be refreshed. */
    suspend fun validSession(): Session? {
        val saved = load() ?: return null
        if (saved.expiresAt > Instant.now().epochSecond + 60) return saved
        return try {
            val json = post("/auth/v1/token?grant_type=refresh_token",
                buildJsonObject { put("refresh_token", saved.refreshToken) }, RemoteCatalog.key)
            session(json, saved.provider).also { store(it) }
        } catch (_: Rejected) {
            clear() // The refresh token is no longer valid: signed out.
            null
        } catch (_: Exception) {
            null // Offline: try again later.
        }
    }

    val isSignedIn: Boolean get() = load() != null
    val provider: String? get() = load()?.provider

    suspend fun signOut() {
        load()?.let { runCatching { post("/auth/v1/logout", JsonObject(emptyMap()), it.accessToken) } }
        clear()
    }

    /** Deletes the account and everything saved online (Edge Function `delete-account`), then signs out. */
    suspend fun deleteAccount() {
        val session = validSession() ?: throw IOException("No session")
        post("/functions/v1/delete-account", JsonObject(emptyMap()), session.accessToken)
        clear()
    }

    /** A random nonce, and its SHA-256 (hex) to give to Google. */
    fun makeNonce(): Pair<String, String> {
        val bytes = ByteArray(32).also { SecureRandom().nextBytes(it) }
        val raw = bytes.joinToString("") { "%02x".format(it) }
        val hashed = MessageDigest.getInstance("SHA-256").digest(raw.toByteArray()).joinToString("") { "%02x".format(it) }
        return raw to hashed
    }

    // MARK: Requests

    suspend fun post(path: String, body: JsonObject, bearer: String): JsonObject = withContext(Dispatchers.IO) {
        val connection = URL(RemoteCatalog.base + path).openConnection() as HttpURLConnection
        connection.requestMethod = "POST"
        connection.connectTimeout = 20_000
        connection.readTimeout = 20_000
        connection.doOutput = true
        connection.setRequestProperty("Content-Type", "application/json")
        connection.setRequestProperty("apikey", RemoteCatalog.key)
        connection.setRequestProperty("Authorization", "Bearer $bearer")
        try {
            connection.outputStream.use { it.write(body.toString().toByteArray()) }
            val status = connection.responseCode
            val text = (if (status in 200..299) connection.inputStream else connection.errorStream)
                ?.bufferedReader()?.use { it.readText() } ?: ""
            val json = runCatching { AppJson.parseToJsonElement(text).jsonObject }.getOrDefault(JsonObject(emptyMap()))
            if (status !in 200..299) {
                val reason = listOf("error_description", "msg", "message").firstNotNullOfOrNull { (json[it] as? JsonPrimitive)?.content }
                throw Rejected(reason ?: "HTTP $status")
            }
            json
        } finally {
            connection.disconnect()
        }
    }

    private fun session(json: JsonObject, provider: String): Session {
        fun str(o: JsonObject?, k: String) = (o?.get(k) as? JsonPrimitive)?.takeIf { it.isString }?.content
        val access = str(json, "access_token") ?: throw IOException("Invalid response")
        val refresh = str(json, "refresh_token") ?: throw IOException("Invalid response")
        val id = str(json["user"] as? JsonObject, "id") ?: throw IOException("Invalid response")
        val expiresIn = (json["expires_in"] as? JsonPrimitive)?.doubleOrNull ?: 3600.0
        val expiresAt = (json["expires_at"] as? JsonPrimitive)?.doubleOrNull ?: (Instant.now().epochSecond + expiresIn)
        return Session(access, refresh, expiresAt, id, provider)
    }

    // MARK: Storage

    private fun store(session: Session) {
        prefs.edit().putString(sessionKey, AppJson.encodeToString(Session.serializer(), session)).apply()
    }

    private fun load(): Session? = try {
        prefs.getString(sessionKey, null)?.let { AppJson.decodeFromString(Session.serializer(), it) }
    } catch (_: Exception) { null }

    private fun clear() { prefs.edit().remove(sessionKey).apply() }
}

/**
 * The profile and progress saved online: one row per user in `user_progress`, readable and writable only
 * by its owner (row level security). The phone stays the reference; the online copy lets the progress come
 * back on another phone (iPhone or Android) or after reinstalling.
 */
object ProgressSync {
    @Serializable private data class Row(val profile: Profile)
    @Serializable private data class Upsert(val user_id: String, val profile: Profile, val updated_at: String)

    /** The saved profile of the signed-in user (null if there is none yet). */
    suspend fun pull(session: SupabaseAuth.Session): Profile? = withContext(Dispatchers.IO) {
        val (status, body) = RemoteCatalog.get(
            "${RemoteCatalog.base}/rest/v1/user_progress?select=profile&user_id=eq.${session.userId}", session.accessToken)
        if (status != 200) throw IOException("HTTP $status")
        AppJson.decodeFromString(ListSerializer(Row.serializer()), body).firstOrNull()?.profile
    }

    suspend fun push(profile: Profile, session: SupabaseAuth.Session) = withContext(Dispatchers.IO) {
        val connection = URL("${RemoteCatalog.base}/rest/v1/user_progress?on_conflict=user_id").openConnection() as HttpURLConnection
        connection.requestMethod = "POST"
        connection.connectTimeout = 20_000
        connection.readTimeout = 20_000
        connection.doOutput = true
        connection.setRequestProperty("Content-Type", "application/json")
        connection.setRequestProperty("Prefer", "resolution=merge-duplicates,return=minimal")
        connection.setRequestProperty("apikey", RemoteCatalog.key)
        connection.setRequestProperty("Authorization", "Bearer ${session.accessToken}")
        try {
            val body = AppJson.encodeToString(Upsert.serializer(), Upsert(session.userId, profile, Instant.now().toString()))
            connection.outputStream.use { it.write(body.toByteArray()) }
            val status = connection.responseCode
            if (status !in 200..299) throw IOException("HTTP $status")
        } finally {
            connection.disconnect()
        }
    }
}
