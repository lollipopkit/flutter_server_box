package tech.lolli.toolbox.incoming

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class IncomingFilesTest {
    @Test
    fun sanitizeKeepsOneSegment() {
        assertEquals("passwd", IncomingFiles.sanitize("../../etc/passwd"))
        assertEquals("evil.txt", IncomingFiles.sanitize("C:\\dir\\evil.txt"))
        assertEquals("ab", IncomingFiles.sanitize("a\u0000b"))
        assertEquals("file", IncomingFiles.sanitize(".."))
        assertEquals("file", IncomingFiles.sanitize("."))
        assertEquals("file", IncomingFiles.sanitize("  "))
        assertEquals("file", IncomingFiles.sanitize(null))
        assertEquals("report.pdf", IncomingFiles.sanitize("report.pdf"))
    }

    @Test
    fun sanitizeCutsLongNamesBeforeTheExtension() {
        val name = IncomingFiles.sanitize("文".repeat(200) + ".tar.gz")
        assertTrue(name.toByteArray().size <= 255)
        assertTrue(name.endsWith(".gz"))
    }

    @Test
    fun uniqueNumbersRepeats() {
        val taken = mutableSetOf<String>()
        assertEquals("a.txt", IncomingFiles.unique("a.txt", taken))
        assertEquals("a (2).txt", IncomingFiles.unique("a.txt", taken))
        assertEquals("a (3).txt", IncomingFiles.unique("a.txt", taken))
        assertEquals("Makefile", IncomingFiles.unique("Makefile", taken))
        assertEquals("Makefile (2)", IncomingFiles.unique("Makefile", taken))
    }

    @Test
    fun uniqueStaysUnderTheLimitAndTerminates() {
        val full = "a".repeat(251) + ".txt"
        val taken = mutableSetOf<String>()
        assertEquals(full, IncomingFiles.unique(full, taken))
        val second = IncomingFiles.unique(full, taken)
        assertTrue(second.endsWith(" (2).txt"))
        assertTrue(second.toByteArray().size <= 255)
        val third = IncomingFiles.unique(full, taken)
        assertTrue(third.endsWith(" (3).txt"))
    }
}
