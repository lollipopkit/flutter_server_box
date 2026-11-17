package tech.lolli.toolbox.widget

import java.io.IOException
import java.net.InetAddress
import java.net.ServerSocket
import java.util.concurrent.atomic.AtomicInteger
import kotlin.concurrent.thread
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

/** `WidgetServer.fallbackAddr`: the same agent at a second address. */
class WidgetFallbackTest {
    private val servers = mutableListOf<ServerSocket>()

    @After
    fun stop() = servers.forEach { it.close() }

    /** An agent on loopback answering [code] to every request, counting them. */
    private fun agent(code: Int = 200): Pair<String, () -> Int> {
        val hits = AtomicInteger()
        val server = ServerSocket(0, 50, InetAddress.getLoopbackAddress())
        servers.add(server)
        thread(isDaemon = true) {
            while (!server.isClosed) {
                val socket = runCatching { server.accept() }.getOrNull() ?: break
                socket.use { s ->
                    val reader = s.getInputStream().bufferedReader()
                    // The request line and headers, up to the blank line.
                    while (!reader.readLine().isNullOrEmpty()) Unit
                    hits.incrementAndGet()
                    val body = "{}"
                    s.getOutputStream().write(
                        ("HTTP/1.1 $code X\r\nContent-Type: application/json\r\n" +
                            "Content-Length: ${body.length}\r\nConnection: close\r\n\r\n$body")
                            .toByteArray(),
                    )
                }
            }
        }
        return "http://127.0.0.1:${server.localPort}" to { hits.get() }
    }

    /** An address nothing listens on: a port bound and given back. */
    private fun closed(): String {
        val port = ServerSocket(0).use { it.localPort }
        return "http://127.0.0.1:$port"
    }

    private fun server(addr: String, fallback: String?) = WidgetStore.WidgetServer(
        id = "s1",
        name = "s1",
        addr = addr,
        fallbackAddr = fallback,
        certSha256 = null,
        // Loopback is sendable without it; set so the test does not depend on that.
        allowInsecure = true,
        tokenExpiresAt = 0,
    )

    @Test
    fun anAddressThatCannotBeConnectedToMovesToTheFallback() {
        val (addr, hits) = agent()
        assertEquals("{}", WidgetApi.get(server(closed(), addr), "/api/v1/metrics", "t"))
        assertEquals(1, hits())
    }

    @Test
    fun anAnswerIsTheAgentAndIsNotRetriedElsewhere() {
        val (addr, _) = agent(code = 500)
        val (fallback, fallbackHits) = agent()
        assertThrows(IOException::class.java) {
            WidgetApi.get(server(addr, fallback), "/api/v1/metrics", "t")
        }
        assertEquals(0, fallbackHits())
    }

    @Test
    fun neitherAnsweringFails() {
        val e = assertThrows(IOException::class.java) {
            WidgetApi.get(server(closed(), closed()), "/api/v1/metrics", "t")
        }
        assertTrue(e !is WidgetApi.RejectedTokenException)
    }
}
