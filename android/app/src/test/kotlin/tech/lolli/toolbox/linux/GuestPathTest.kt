package tech.lolli.toolbox.linux

import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.nio.file.FileVisitResult
import java.nio.file.Files
import java.nio.file.Path
import java.nio.file.Paths
import java.nio.file.SimpleFileVisitor
import java.nio.file.attribute.BasicFileAttributes

/** Against a real tree of links, since the links are the point. */
class GuestPathTest {
    private lateinit var root: Path
    private lateinit var outside: Path
    private val r get() = root.toString()

    private val readLink: (String) -> String? = { p ->
        val path = Paths.get(p)
        if (Files.isSymbolicLink(path)) Files.readSymbolicLink(path).toString() else null
    }

    private fun resolve(guest: String, followLast: Boolean = true) =
        GuestPath.resolve(r, guest, followLast, readLink)

    @Before
    fun setUp() {
        root = Files.createTempDirectory("rootfs").toRealPath()
        outside = Files.createTempDirectory("outside").toRealPath()
        Files.createDirectories(root.resolve("usr/bin"))
        Files.write(root.resolve("usr/bin/mawk"), byteArrayOf(1))
        Files.createDirectories(root.resolve("etc/alternatives"))
        Files.createSymbolicLink(root.resolve("bin"), Paths.get("usr/bin"))
        Files.createSymbolicLink(
            root.resolve("etc/alternatives/awk"),
            Paths.get("/usr/bin/mawk"),
        )
        Files.createSymbolicLink(root.resolve("escape"), Paths.get("../../../../.."))
        Files.createSymbolicLink(root.resolve("host"), outside)
        Files.createSymbolicLink(root.resolve("loop"), Paths.get("loop"))
        Files.createSymbolicLink(root.resolve("dangling"), Paths.get("/nowhere"))
    }

    @After
    fun tearDown() {
        deleteTree(root)
        deleteTree(outside)
    }

    /**
     * Removes [top] and what is in it, a link as the link: never through one.
     *
     * Not `File.deleteRecursively`, which follows links to directories — and
     * this tree has `escape` and `host`, which point out of it on purpose. That
     * deleted whatever was above the test's temporary directory, and on CI it
     * walked the runner for hours.
     */
    private fun deleteTree(top: Path) {
        Files.walkFileTree(
            top,
            object : SimpleFileVisitor<Path>() {
                override fun visitFile(file: Path, attrs: BasicFileAttributes): FileVisitResult {
                    Files.delete(file)
                    return FileVisitResult.CONTINUE
                }

                override fun postVisitDirectory(dir: Path, exc: java.io.IOException?): FileVisitResult {
                    Files.delete(dir)
                    return FileVisitResult.CONTINUE
                }
            },
        )
    }

    @Test
    fun rootIsTheRootfs() = assertEquals(r, resolve("/"))

    @Test
    fun relativeLinkResolvesInsideTheRootfs() =
        assertEquals("$r/usr/bin/mawk", resolve("/bin/mawk"))

    @Test
    fun absoluteLinkIsReadAgainstTheGuestRoot() =
        assertEquals("$r/usr/bin/mawk", resolve("/etc/alternatives/awk"))

    @Test
    fun lastLinkIsKeptWhenNotFollowed() = assertEquals(
        "$r/etc/alternatives/awk",
        resolve("/etc/alternatives/awk", followLast = false),
    )

    @Test
    fun dotDotInALinkStopsAtTheRoot() = assertEquals("$r/usr", resolve("/escape/usr"))

    @Test
    fun dotDotInThePathStopsAtTheRoot() =
        assertEquals("$r/usr/bin", resolve("/../../usr/bin"))

    @Test
    fun hostAbsoluteLinkStaysInsideTheRootfs() =
        assertEquals("$r$outside", resolve("/host"))

    @Test
    fun loopingLinksAreRefused() = assertNull(resolve("/loop"))

    @Test
    fun danglingLinkResolvesUnderTheRoot() =
        assertEquals("$r/nowhere", resolve("/dangling"))

    /** How `isChildDocument` decides a tree grant: on resolved host paths. */
    @Test
    fun containmentIsJudgedOnResolvedPaths() {
        Files.createDirectories(root.resolve("root"))
        Files.createSymbolicLink(root.resolve("root/up"), Paths.get("/"))
        Files.createSymbolicLink(root.resolve("root/alt"), Paths.get("/etc"))
        val granted = resolve("/root")!!
        // Lexically under `/root`, actually `/etc` and `/usr`.
        assertFalse(GuestPath.isWithin(granted, resolve("/root/alt")!!))
        assertFalse(GuestPath.isWithin(granted, resolve("/root/up/usr/bin")!!))
        assertTrue(GuestPath.isWithin(granted, resolve("/root")!!))
        // Through a link into it, a path elsewhere is inside.
        assertTrue(GuestPath.isWithin(resolve("/usr")!!, resolve("/bin/mawk")!!))
    }

    @Test
    fun lexicalHelpers() {
        assertEquals("/a/b/d", GuestPath.normalize("a//b/./c/../d"))
        assertEquals("/x", GuestPath.normalize("/../x"))
        assertEquals("/a", GuestPath.parent("/a/b"))
        assertEquals("/", GuestPath.parent("/"))
        assertEquals("/x", GuestPath.child("/", "x"))
        assertEquals("/", GuestPath.child("/a", ".."))
        assertEquals("b", GuestPath.name("/a/b"))
        assertTrue(GuestPath.isWithin("/a", "/a/b"))
        assertFalse(GuestPath.isWithin("/a", "/ab"))
        assertTrue(GuestPath.isWithin("/", "/x"))
    }
}
