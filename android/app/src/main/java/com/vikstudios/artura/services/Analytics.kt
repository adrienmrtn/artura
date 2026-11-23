package com.vikstudios.artura.services

import android.content.Context
import android.content.SharedPreferences
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import com.vikstudios.artura.BuildConfig
import com.vikstudios.artura.core.AppLanguage
import com.vikstudios.artura.data.RemoteCatalog
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import java.net.HttpURLConnection
import java.net.URL
import java.time.Instant
import java.util.UUID

/**
 * Anonymous usage events, stored in the online database (table `app_events`), exactly like iOS.
 *
 * Each device gets a random identifier; nothing else identifies the person (no name, no e-mail, no Google
 * account). Events are queued, kept on the device until sent, and sent in batches. Can be called from
 * anywhere: the queue is handled on its own thread.
 */
object Analytics {
    private const val deviceKey = "artura.analytics.device"
    private const val queueKey = "artura.analytics.queue"
    private const val batchSize = 25
    private const val maxQueue = 2000

    private lateinit var prefs: SharedPreferences
    private val thread = HandlerThread("artura.analytics").apply { start() }
    private val worker = Handler(thread.looper)

    lateinit var deviceId: String
        private set

    /** Changes at each launch of the app. */
    val sessionId: String = UUID.randomUUID().toString().uppercase()

    /** Set from the subscription status, sent with every event. */
    @Volatile var isPro = false

    /** True in a debug run opened with debug arguments: screenshots stay out of the statistics. */
    @Volatile var disabled = false

    private var queue = mutableListOf<JsonObject>()
    private var sending = false
    private var flushScheduled = false

    private val appVersion = "${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE})"
    private val osVersion = "Android ${Build.VERSION.RELEASE}"

    fun init(context: Context) {
        prefs = context.getSharedPreferences("artura", Context.MODE_PRIVATE)
        deviceId = prefs.getString(deviceKey, null) ?: UUID.randomUUID().toString().uppercase().also {
            prefs.edit().putString(deviceKey, it).apply()
        }
        worker.post {
            queue = try {
                prefs.getString(queueKey, null)?.let { text ->
                    (kotlinx.serialization.json.Json.parseToJsonElement(text) as? JsonArray)?.mapNotNull { it as? JsonObject }?.toMutableList()
                } ?: mutableListOf()
            } catch (_: Exception) { mutableListOf() }
        }
    }

    /** Records an event. Properties hold plain values: strings, numbers, booleans, lists and maps of those. */
    fun track(name: String, properties: Map<String, Any?> = emptyMap()) {
        if (disabled) return
        val date = Instant.now().toString()
        val language = AppLanguage.code
        val pro = isPro
        worker.post { enqueue(name, properties, date, language, pro) }
    }

    private fun enqueue(name: String, properties: Map<String, Any?>, date: String, language: String, pro: Boolean) {
        val row = JsonObject(mapOf(
            "occurred_at" to JsonPrimitive(date),
            "device_id" to JsonPrimitive(deviceId),
            "session_id" to JsonPrimitive(sessionId),
            "name" to JsonPrimitive(name),
            "properties" to JsonObject(properties.mapNotNull { (k, v) -> plain(v)?.let { k to it } }.toMap()),
            "language" to JsonPrimitive(language),
            "app_version" to JsonPrimitive(appVersion),
            "os_version" to JsonPrimitive(osVersion),
            "is_pro" to JsonPrimitive(pro),
        ))
        queue.add(row)
        if (queue.size > maxQueue) queue.subList(0, queue.size - maxQueue).clear()
        save()
        if (queue.size >= batchSize) {
            send()
        } else if (!flushScheduled) {
            flushScheduled = true
            worker.postDelayed({ flushScheduled = false; send() }, 8000)
        }
    }

    /** Sends what is waiting. Called regularly, and when the app goes to the background. */
    fun flush() { worker.post { send() } }

    private fun send() {
        if (sending || queue.isEmpty()) return
        val batch = queue.take(100)
        sending = true
        Thread {
            val status = try {
                val connection = URL("${RemoteCatalog.base}/rest/v1/app_events").openConnection() as HttpURLConnection
                connection.requestMethod = "POST"
                connection.connectTimeout = 20_000
                connection.readTimeout = 20_000
                connection.doOutput = true
                connection.setRequestProperty("Content-Type", "application/json")
                connection.setRequestProperty("Prefer", "return=minimal")
                connection.setRequestProperty("apikey", RemoteCatalog.key)
                connection.setRequestProperty("Authorization", "Bearer ${RemoteCatalog.key}")
                connection.outputStream.use { it.write(JsonArray(batch).toString().toByteArray()) }
                connection.responseCode.also { connection.disconnect() }
            } catch (_: Exception) { 0 }
            worker.post {
                sending = false
                if (status in 200..299 || status in 400..499) {
                    // Sent (or refused for good: no point retrying a malformed batch).
                    queue.subList(0, minOf(batch.size, queue.size)).clear()
                    save()
                    if (queue.isNotEmpty()) send()
                }
                // Otherwise (offline, server error): kept for the next try.
            }
        }.start()
    }

    private fun save() {
        prefs.edit().putString(queueKey, JsonArray(queue).toString()).apply()
    }

    /** Keeps only values that can be written as JSON. */
    private fun plain(value: Any?): JsonElement? = when (value) {
        null -> null
        is String -> JsonPrimitive(value.take(500))
        is Boolean -> JsonPrimitive(value)
        is Int -> JsonPrimitive(value)
        is Long -> JsonPrimitive(value)
        is Double -> if (value.isFinite()) JsonPrimitive(value) else null
        is Float -> if (value.isFinite()) JsonPrimitive(value.toDouble()) else null
        is Iterable<*> -> JsonArray(value.mapNotNull { plain(it) })
        is Map<*, *> -> JsonObject(value.entries.mapNotNull { (k, v) -> plain(v)?.let { k.toString() to it } }.toMap())
        is JsonElement -> value
        else -> JsonPrimitive(value.toString())
    }

}
