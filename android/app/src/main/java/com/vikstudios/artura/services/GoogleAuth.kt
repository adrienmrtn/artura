package com.vikstudios.artura.services

import android.app.Activity
import androidx.credentials.CredentialManager
import androidx.credentials.CustomCredential
import androidx.credentials.GetCredentialRequest
import androidx.credentials.exceptions.GetCredentialCancellationException
import com.google.android.libraries.identity.googleid.GetSignInWithGoogleOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential

/**
 * Google sign-in with Android's Credential Manager. Google gives an identity token, exchanged for a
 * Supabase session (same account as on iOS, so the progress is shared).
 */
object GoogleAuth {
    /**
     * OAuth client ID of type "Web application", created in Google Cloud Console (the same project as the
     * iOS client), of the form "1234-abcd.apps.googleusercontent.com". Android sign-in asks for a Web client
     * ID; an "Android" client with the package name and the signing certificate's SHA-1 must also exist.
     * Add this ID to Supabase › Authentication › Google › Client IDs. Empty: Google sign-in not configured.
     */
    const val webClientId = "518521814725-jvnj3vg5qrlnf0pihr65shud3bv903ps.apps.googleusercontent.com"

    val isConfigured: Boolean get() = webClientId.isNotEmpty()

    data class Account(val userId: String, val firstName: String?, val idToken: String, val rawNonce: String)

    class Cancelled : Exception()
    class NotConfigured : Exception()

    /** Opens Google sign-in and returns the account. Throws `Cancelled` when the person closes it. */
    suspend fun signIn(activity: Activity): Account {
        if (!isConfigured) throw NotConfigured()
        val (raw, hashed) = SupabaseAuth.makeNonce()
        val option = GetSignInWithGoogleOption.Builder(webClientId).setNonce(hashed).build()
        val request = GetCredentialRequest.Builder().addCredentialOption(option).build()
        val result = try {
            CredentialManager.create(activity).getCredential(activity, request)
        } catch (_: GetCredentialCancellationException) {
            throw Cancelled()
        }
        val credential = result.credential
        if (credential !is CustomCredential || credential.type != GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL) {
            throw IllegalStateException("Unexpected credential")
        }
        val google = GoogleIdTokenCredential.createFrom(credential.data)
        val sub = jwtSubject(google.idToken) ?: google.id
        return Account(sub, google.givenName, google.idToken, raw)
    }

    private fun jwtSubject(token: String): String? = runCatching {
        val payload = String(android.util.Base64.decode(token.split(".")[1], android.util.Base64.URL_SAFE or android.util.Base64.NO_PADDING or android.util.Base64.NO_WRAP))
        Regex("\"sub\"\\s*:\\s*\"([^\"]+)\"").find(payload)?.groupValues?.get(1)
    }.getOrNull()
}
