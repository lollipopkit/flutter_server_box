package tech.lolli.toolbox.widget

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Where the home-screen widget finds the server list and the credential to
 * fetch it with.
 *
 * Two stores, mirroring the iOS side:
 *
 * - The **list** — name, address, certificate handling — is not secret and
 *   lives in ordinary app preferences. The configuration screen has to read it
 *   before the user has picked anything, since it *is* what they pick from.
 * - The **token** is encrypted with a key held in the Android Keystore, whose
 *   private half never leaves it. App-private storage is already sandboxed, so
 *   this buys nothing against another app; what it buys is that an `adb backup`,
 *   a rooted read, or a stray file copy yields ciphertext with no key beside it.
 *
 * Both are readable from the widget without a channel hop, because an
 * `AppWidgetProvider` is a `BroadcastReceiver` in this app's own process — the
 * thing iOS needs a shared Keychain group for.
 */
object WidgetStore {
    private const val TAG = "WidgetStore"

    /** The list. Deliberately *not* Flutter's shared preferences file: this is
     *  written by native code and read by native code, and putting it beside
     *  the Dart key-value pairs would invite one to be mistaken for the other. */
    private const val PREFS = "sbm_widget_servers"
    private const val KEY_SERVERS = "servers"

    private const val TOKEN_PREFS = "sbm_widget_tokens"
    private const val KEYSTORE = "AndroidKeyStore"
    private const val KEY_ALIAS = "sbm_widget_token_key"

    /** GCM's nonce. 12 bytes is what the mode is specified around; anything
     *  else forces a slower derivation and buys nothing. */
    private const val IV_BYTES = 12
    private const val TAG_BITS = 128

    // MARK: - Servers

    data class WidgetServer(
        val id: String,
        val name: String,
        /** Base address of the agent, no trailing slash. */
        val addr: String,
        val ignoreCert: Boolean,
        /**
         * Whether this server was opted in to plaintext HTTP in the app.
         *
         * Carried rather than inferred from the scheme. `usesCleartextTraffic`
         * in the manifest lets this *process* speak plaintext at all; it says
         * nothing about whether a given server's owner agreed to put a bearer
         * token on an unencrypted wire. That answer is
         * `MonitorHttpCredential.allowInsecure`, and this is it.
         */
        val allowInsecure: Boolean,
        /** When the stored token lapses, seconds since epoch. Zero means there
         *  is none — the app could not reach the agent when it last published. */
        val tokenExpiresAt: Long,
    ) {
        fun toJson(): JSONObject = JSONObject()
            .put("id", id)
            .put("name", name)
            .put("addr", addr)
            .put("ignoreCert", ignoreCert)
            .put("allowInsecure", allowInsecure)
            .put("tokenExpiresAt", tokenExpiresAt)

        companion object {
            fun fromJson(o: JSONObject): WidgetServer? {
                val id = o.optString("id").takeIf { it.isNotEmpty() } ?: return null
                val addr = o.optString("addr").takeIf { it.isNotEmpty() } ?: return null
                return WidgetServer(
                    id = id,
                    name = o.optString("name").takeIf { it.isNotEmpty() } ?: addr,
                    addr = addr,
                    ignoreCert = o.optBoolean("ignoreCert", false),
                    allowInsecure = o.optBoolean("allowInsecure", false),
                    tokenExpiresAt = o.optLong("tokenExpiresAt", 0L),
                )
            }
        }
    }

    fun servers(context: Context): List<WidgetServer> {
        val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_SERVERS, null) ?: return emptyList()
        return try {
            val arr = JSONArray(raw)
            (0 until arr.length()).mapNotNull { WidgetServer.fromJson(arr.getJSONObject(it)) }
        } catch (e: Exception) {
            Log.w(TAG, "Could not read the widget server list: ${e.message}")
            emptyList()
        }
    }

    fun server(context: Context, id: String): WidgetServer? =
        servers(context).firstOrNull { it.id == id }

    /**
     * Replaces the whole list, and drops the token of anything no longer in it.
     *
     * A full replacement rather than a merge: the app publishes the entire set
     * every time, so a server deleted there must not keep a live credential
     * here — and a merge has no way to notice one is gone.
     */
    fun setServers(context: Context, servers: List<WidgetServer>) {
        val arr = JSONArray()
        servers.forEach { arr.put(it.toJson()) }
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_SERVERS, arr.toString())
            .apply()

        val live = servers.map { it.id }.toSet()
        val tokenPrefs = context.getSharedPreferences(TOKEN_PREFS, Context.MODE_PRIVATE)
        val stale = tokenPrefs.all.keys.filterNot { live.contains(it) }
        if (stale.isNotEmpty()) {
            tokenPrefs.edit().apply { stale.forEach { remove(it) } }.apply()
        }
    }

    // MARK: - Tokens

    fun token(context: Context, id: String): String? {
        val stored = context.getSharedPreferences(TOKEN_PREFS, Context.MODE_PRIVATE)
            .getString(id, null) ?: return null
        return try {
            val blob = Base64.decode(stored, Base64.NO_WRAP)
            if (blob.size <= IV_BYTES) return null
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(
                Cipher.DECRYPT_MODE,
                secretKey(),
                GCMParameterSpec(TAG_BITS, blob, 0, IV_BYTES),
            )
            String(cipher.doFinal(blob, IV_BYTES, blob.size - IV_BYTES), Charsets.UTF_8)
        } catch (e: Exception) {
            // A key the Keystore no longer has — a restore onto another device,
            // or a lock-screen change that invalidated it. The ciphertext is
            // unreadable for good, so drop it and let the app publish again
            // rather than keep answering with something that cannot be decrypted.
            Log.w(TAG, "Dropping an undecryptable widget token: ${e.message}")
            setToken(context, id, null)
            null
        }
    }

    fun setToken(context: Context, id: String, token: String?) {
        val prefs = context.getSharedPreferences(TOKEN_PREFS, Context.MODE_PRIVATE)
        if (token.isNullOrEmpty()) {
            prefs.edit().remove(id).apply()
            return
        }
        try {
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.ENCRYPT_MODE, secretKey())
            val encrypted = cipher.doFinal(token.toByteArray(Charsets.UTF_8))
            // The IV is generated by the cipher and must travel with the
            // ciphertext; GCM with a repeated nonce under one key is broken
            // outright, which is why it is never chosen here.
            val blob = cipher.iv + encrypted
            prefs.edit().putString(id, Base64.encodeToString(blob, Base64.NO_WRAP)).apply()
        } catch (e: Exception) {
            // Storing nothing is the safe direction: the widget shows that it
            // cannot reach the agent, and the app publishes again next launch.
            Log.w(TAG, "Could not store a widget token: ${e.message}")
            prefs.edit().remove(id).apply()
        }
    }

    private fun secretKey(): SecretKey {
        val keyStore = KeyStore.getInstance(KEYSTORE).apply { load(null) }
        (keyStore.getEntry(KEY_ALIAS, null) as? KeyStore.SecretKeyEntry)?.let { return it.secretKey }

        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, KEYSTORE)
        generator.init(
            KeyGenParameterSpec.Builder(
                KEY_ALIAS,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                // Not tied to the lock screen. A widget refreshes while the
                // device sits locked in a pocket, which is exactly when a
                // user-authentication requirement would refuse — the widget
                // would then be blank precisely when it is being looked at.
                .setUserAuthenticationRequired(false)
                .build()
        )
        return generator.generateKey()
    }

    // MARK: - The channel payload

    /**
     * Splits `WidgetSync`'s payload between the two stores: the list into
     * preferences, every token into the Keystore-backed one.
     *
     * An entry with no `token` keeps whatever is already stored for it. The app
     * publishes the full list on every change, and an agent that happened to be
     * unreachable when it did so must not cost the widget a working credential.
     */
    fun publish(context: Context, payload: String): Boolean {
        return try {
            val root = JSONObject(payload)
            val raw = root.optJSONArray("servers") ?: JSONArray()
            val servers = ArrayList<WidgetServer>(raw.length())
            for (i in 0 until raw.length()) {
                val entry = raw.optJSONObject(i) ?: continue
                val parsed = WidgetServer.fromJson(entry) ?: continue

                val token = entry.optString("token")
                if (token.isNotEmpty()) setToken(context, parsed.id, token)

                val expiresAt = entry.optLong("expiresAt", 0L)
                servers.add(
                    parsed.copy(
                        tokenExpiresAt = if (expiresAt > 0) {
                            expiresAt
                        } else {
                            server(context, parsed.id)?.tokenExpiresAt ?: 0L
                        }
                    )
                )
            }
            setServers(context, servers)
            true
        } catch (e: Exception) {
            Log.e(TAG, "Could not publish the widget server list: ${e.message}", e)
            false
        }
    }

    /**
     * What is actually held, as JSON — never the tokens themselves.
     *
     * The token store is consulted per server rather than trusting the stored
     * `tokenExpiresAt`, because the two can disagree: a Keystore key can be
     * lost while the preferences survive, and a renewal decision made from a
     * deadline whose credential no longer decrypts would skip that server for
     * as long as the deadline says it is fine.
     */
    fun tokenState(context: Context): String {
        val arr = JSONArray()
        for (server in servers(context)) {
            if (token(context, server.id) == null) continue
            arr.put(
                JSONObject()
                    .put("id", server.id)
                    .put("endpoint", server.addr)
                    .put("expiresAt", server.tokenExpiresAt)
            )
        }
        return arr.toString()
    }
}
