package tech.lolli.toolbox

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.core.content.pm.ShortcutInfoCompat
import androidx.core.content.pm.ShortcutManagerCompat
import androidx.core.graphics.drawable.IconCompat
import org.json.JSONArray

/**
 * Launcher shortcuts to servers: the long-press list (dynamic) and the ones
 * pinned to the home screen.
 *
 * Each opens a `serverbox://` link, so a shortcut goes through `AppLink` and
 * can do nothing a link could not.
 */
object AppShortcuts {
    private const val PREFIX = "server:"

    class Entry(val id: String, val label: String, val uri: String)

    /**
     * [json] is `[{"id","label","uri"}]` in the order to list them. Replaces
     * the dynamic list; a pinned shortcut whose server is gone is disabled
     * rather than left to open nothing.
     */
    fun publish(context: Context, json: String) {
        val entries = parse(json)
        val max = ShortcutManagerCompat.getMaxShortcutCountPerActivity(context)
        ShortcutManagerCompat.setDynamicShortcuts(
            context,
            entries.take(max).mapIndexed { rank, e -> build(context, e, rank) },
        )
        val live = entries.associateBy { PREFIX + it.id }
        val pinned = ShortcutManagerCompat.getShortcuts(context, ShortcutManagerCompat.FLAG_MATCH_PINNED)
        val gone = pinned.map { it.id }.filter { it.startsWith(PREFIX) && it !in live }
        if (gone.isNotEmpty()) {
            ShortcutManagerCompat.disableShortcuts(context, gone, context.getString(R.string.shortcut_server_gone))
        }
        // A server back from a restore gets its pinned shortcut back, renamed
        // if it was.
        val back = pinned.mapNotNull { live[it.id] }
        if (back.isNotEmpty()) {
            val infos = back.map { build(context, it, 0) }
            ShortcutManagerCompat.enableShortcuts(context, infos)
            ShortcutManagerCompat.updateShortcuts(context, infos)
        }
    }

    /** Asks the launcher to pin [entry]; false when it cannot. */
    fun requestPin(context: Context, entry: Entry): Boolean {
        if (!ShortcutManagerCompat.isRequestPinShortcutSupported(context)) return false
        return ShortcutManagerCompat.requestPinShortcut(context, build(context, entry, 0), null)
    }

    fun parse(json: String): List<Entry> {
        val arr = JSONArray(json)
        return (0 until arr.length()).mapNotNull { i ->
            val o = arr.optJSONObject(i) ?: return@mapNotNull null
            entry(o.optString("id"), o.optString("label"), o.optString("uri"))
        }
    }

    /** Null unless all three are there and the link is this app's own. */
    fun entry(id: String?, label: String?, uri: String?): Entry? =
        if (id.isNullOrEmpty() || label.isNullOrEmpty() || uri == null || !uri.startsWith("serverbox://")) null
        else Entry(id, label, uri)

    private fun build(context: Context, e: Entry, rank: Int): ShortcutInfoCompat =
        ShortcutInfoCompat.Builder(context, PREFIX + e.id)
            .setShortLabel(e.label)
            .setLongLabel(e.label)
            .setIcon(IconCompat.createWithResource(context, R.drawable.ic_shortcut_server))
            .setIntent(
                Intent(Intent.ACTION_VIEW, Uri.parse(e.uri), context, MainActivity::class.java)
                    .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP),
            )
            .setRank(rank)
            .build()
}
