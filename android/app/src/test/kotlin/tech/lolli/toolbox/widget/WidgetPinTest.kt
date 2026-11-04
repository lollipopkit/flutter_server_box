package tech.lolli.toolbox.widget

import org.junit.Assert.assertEquals
import org.junit.Test

class WidgetPinTest {
    /** The form `MonitorHttpCredential.certSha256` holds: lowercase hex. */
    @Test
    fun pinIsSha256InLowercaseHex() {
        assertEquals(
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
            WidgetApi.sha256Hex("abc".toByteArray()),
        )
    }

    /** The colon form `openssl x509 -fingerprint -sha256` prints reads the same. */
    @Test
    fun pinIsReadAsRustReadsIt() {
        assertEquals("ab12cd", WidgetApi.normalizePin("AB:12 cd-"))
    }
}
