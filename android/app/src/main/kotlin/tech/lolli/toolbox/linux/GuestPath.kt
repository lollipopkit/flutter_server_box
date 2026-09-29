package tech.lolli.toolbox.linux

/**
 * Paths inside a Linux rootfs, resolved the way the guest resolves them.
 *
 * A rootfs is full of symlinks written for the guest: `/bin -> usr/bin`, and
 * absolute ones like `/etc/alternatives/awk -> /usr/bin/mawk`. Opened as host
 * paths, the kernel resolves an absolute target against the *phone's* `/`, so
 * browsing `/bin` would list Android's own directory, and a link planted from
 * inside the guest (`ln -s /data/data/<this app> /root/x`) would hand out the
 * app's private files. Every path here is resolved one component at a time
 * against the rootfs instead, so what comes out has no symlink left in it
 * except, when asked for, the last component.
 *
 * Pure, with the filesystem passed in, so it can be exercised without one.
 */
internal object GuestPath {
    /** The most links one lookup follows, as Linux's `MAXSYMLINKS`. */
    private const val MAX_LINKS = 40

    /** [path] made absolute and free of `.`, `..` and repeated separators. */
    fun normalize(path: String): String = "/" + segments(path).joinToString("/")

    fun parent(path: String): String {
        val parts = segments(path)
        return if (parts.isEmpty()) "/" else "/" + parts.dropLast(1).joinToString("/")
    }

    fun child(parent: String, name: String): String =
        normalize(if (parent.endsWith("/")) "$parent$name" else "$parent/$name")

    fun name(path: String): String = segments(path).lastOrNull() ?: ""

    /** Whether [path] is [ancestor] or somewhere under it, lexically. */
    fun isWithin(ancestor: String, path: String): Boolean {
        val a = normalize(ancestor)
        val p = normalize(path)
        return a == "/" || p == a || p.startsWith("$a/")
    }

    /**
     * The host path [guest] names under [root], or null for a lookup that
     * loops.
     *
     * [readLink] answers a host path's link target, or null for anything that
     * is not a link. [followLast] follows a link in the final component too —
     * reading and writing do, deleting and renaming act on the link itself.
     */
    fun resolve(
        root: String,
        guest: String,
        followLast: Boolean,
        readLink: (String) -> String?,
    ): String? {
        val pending = ArrayDeque(segments(guest, clamp = false))
        val done = ArrayList<String>()
        var links = 0
        while (pending.isNotEmpty()) {
            val part = pending.removeFirst()
            when (part) {
                "." -> continue
                // Never above the rootfs: the guest's `/..` is its `/`.
                ".." -> {
                    if (done.isNotEmpty()) done.removeAt(done.size - 1)
                    continue
                }
            }
            val host = join(root, done + part)
            val target = if (pending.isEmpty() && !followLast) null else readLink(host)
            if (target == null) {
                done.add(part)
                continue
            }
            if (++links > MAX_LINKS) return null
            if (target.startsWith("/")) done.clear()
            // What the link says replaces it, and is itself looked up
            // component by component: it may hold links and `..` of its own.
            segments(target, clamp = false).asReversed().forEach(pending::addFirst)
        }
        return join(root, done)
    }

    private fun join(root: String, parts: List<String>): String =
        if (parts.isEmpty()) root else root.trimEnd('/') + "/" + parts.joinToString("/")

    /**
     * The non-empty components of [path]. With [clamp], `.` is dropped and
     * `..` taken back lexically, never above the top; without it both are
     * kept for [resolve] to handle after the links before them.
     */
    private fun segments(path: String, clamp: Boolean = true): List<String> {
        val out = ArrayList<String>()
        for (part in path.split('/')) {
            if (part.isEmpty()) continue
            if (!clamp) {
                out.add(part)
                continue
            }
            when (part) {
                "." -> {}
                ".." -> if (out.isNotEmpty()) out.removeAt(out.size - 1)
                else -> out.add(part)
            }
        }
        return out
    }
}
