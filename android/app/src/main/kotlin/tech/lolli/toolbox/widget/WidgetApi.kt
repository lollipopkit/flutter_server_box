package tech.lolli.toolbox.widget

import android.content.Context
import android.net.Uri
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL

/**
 * Reads one server's `/api/v1/metrics` and `/api/v1/metrics/history` with the
 * scoped, read-only token the app obtained from the agent.
 *
 * The widget fetches for itself rather than being fed by the app, for the same
 * reason the watch does: a widget refreshes on the system's schedule, and one
 * that only showed what the app last saw would be as stale as the last time
 * someone opened it.
 */
object WidgetApi {
    /**
     * A refusal that is a decision rather than a fault, and has to read as one.
     *
     * "Network error" for a plaintext address the user never opted in to would
     * send them looking at their Wi-Fi.
     */
    class InsecureException : IOException("HTTPS required")

    class MissingTokenException : IOException("No credential")

    /** One reading, reduced to what a widget shows. */
    data class Reading(
        val name: String,
        val cpu: Double?,
        val mem: Double?,
        val disk: Double?,
        val memText: String,
        val diskText: String,
        val netText: String,
    )

    /** One bucket of the agent's stored history, oldest first. */
    data class HistoryPoint(
        val cpu: Double,
        val memory: Double,
        val disk: Double,
        val netRx: Double,
        val netTx: Double,
    )

    private const val TIMEOUT_MS = 8_000

    suspend fun load(
        context: Context,
        server: WidgetStore.WidgetServer,
    ): Pair<Reading, List<HistoryPoint>> = withContext(Dispatchers.IO) {
        val token = WidgetStore.token(context, server.id) ?: throw MissingTokenException()
        val reading = parseMetrics(server, get(server, "/api/v1/metrics", token))
        // History failing is not fatal: an agent that has just started has
        // none, and numbers with no chart beat an error.
        val history = try {
            parseHistory(get(server, "/api/v1/metrics/history?minutes=180", token))
        } catch (_: Exception) {
            emptyList()
        }
        reading to history
    }

    /**
     * Whether this connection may carry a credential.
     *
     * The same question the app asks before every request. Loopback counts as
     * secure without TLS — the reverse-proxy-on-the-same-host case, which
     * really is encrypted — and everything else in plaintext needs the
     * server's own opt-in.
     *
     * Distinct from `usesCleartextTraffic` in the manifest, which answers
     * whether this *process* may speak plaintext at all. That flag is what
     * makes an `http://` request possible; this is what decides whether one is
     * allowed to carry a bearer token.
     */
    private fun isSendable(server: WidgetStore.WidgetServer, url: URL): Boolean {
        if (url.protocol.equals("https", ignoreCase = true)) return true
        if (server.allowInsecure) return true
        val host = url.host?.lowercase() ?: return false
        return host == "localhost" || host == "127.0.0.1" || host == "::1" || host == "[::1]"
    }

    private fun get(
        server: WidgetStore.WidgetServer,
        path: String,
        token: String,
    ): String {
        val base = server.addr.trimEnd('/')
        val url = URL(base + path)
        if (!isSendable(server, url)) throw InsecureException()

        var connection: HttpURLConnection? = null
        try {
            connection = (url.openConnection() as HttpURLConnection).apply {
                requestMethod = "GET"
                connectTimeout = TIMEOUT_MS
                readTimeout = TIMEOUT_MS
                setRequestProperty("Authorization", "Bearer $token")
                setRequestProperty("Accept", "application/json")
                setRequestProperty("User-Agent", "ServerBox-Widget/2")
            }
            if (connection.responseCode !in 200..299) {
                throw IOException("HTTP ${connection.responseCode}")
            }
            return connection.inputStream.bufferedReader().use { it.readText() }
        } finally {
            connection?.disconnect()
        }
    }

    private fun parseMetrics(server: WidgetStore.WidgetServer, body: String): Reading {
        val o = JSONObject(body)
        val mem = o.optJSONObject("memory") ?: JSONObject()
        val disk = o.optJSONObject("disk") ?: JSONObject()
        val net = o.optJSONObject("network") ?: JSONObject()
        return Reading(
            name = o.optString("server_name").ifEmpty { server.name },
            cpu = o.optDoubleOrNull("cpu_usage"),
            mem = mem.optDoubleOrNull("usage_percent"),
            disk = disk.optDoubleOrNull("usage_percent"),
            memText = "${formatBytes(mem.optDouble("used", 0.0))} / ${formatBytes(mem.optDouble("total", 0.0))}",
            diskText = "${formatBytes(disk.optDouble("used", 0.0))} / ${formatBytes(disk.optDouble("total", 0.0))}",
            netText = "${formatBytes(net.optDouble("rx_bytes", 0.0))} / ${formatBytes(net.optDouble("tx_bytes", 0.0))}",
        )
    }

    private fun parseHistory(body: String): List<HistoryPoint> {
        val arr = JSONArray(body)
        return (0 until arr.length()).mapNotNull { i ->
            val o = arr.optJSONObject(i) ?: return@mapNotNull null
            HistoryPoint(
                cpu = o.optDouble("cpu", 0.0),
                memory = o.optDouble("memory", 0.0),
                disk = o.optDouble("disk", 0.0),
                netRx = o.optDouble("net_rx_speed", 0.0),
                netTx = o.optDouble("net_tx_speed", 0.0),
            )
        }
    }

    /**
     * Null rather than 0 for a reading the agent did not report.
     *
     * A source that could not measure something must not look like a machine
     * sitting idle — the widget renders null as "--".
     */
    private fun JSONObject.optDoubleOrNull(key: String): Double? =
        if (has(key) && !isNull(key)) optDouble(key).takeIf { !it.isNaN() } else null

    /** Byte counts the way the rest of the app prints them ("1.3g"). */
    fun formatBytes(bytes: Double): String {
        val units = listOf("b", "k", "m", "g", "t", "p")
        var value = bytes.coerceAtLeast(0.0)
        var idx = 0
        while (value >= 1024 && idx < units.size - 1) {
            value /= 1024
            idx++
        }
        return if (idx == 0) "${value.toInt()}${units[idx]}" else String.format("%.1f%s", value, units[idx])
    }

    /** A host to show in a list, without the scheme or the port. */
    fun displayHost(addr: String): String =
        runCatching { Uri.parse(addr).host ?: addr }.getOrDefault(addr)
}
