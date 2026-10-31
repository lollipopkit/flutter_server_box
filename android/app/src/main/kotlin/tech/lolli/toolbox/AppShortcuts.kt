package tech.lolli.toolbox

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.core.content.pm.ShortcutInfoCompat
import androidx.core.content.pm.ShortcutManagerCompat
import androidx.core.graphics.drawable.IconCompat
import org.json.JSONArray
import org.json.JSONObject

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
     * [json] is `{"listed":[…],"all":[…]}`, each `[{"id","label","uri"}]`:
     * the long-press list in order, and every server. A pinned shortcut is
     * kept, renamed, while its server exists anywhere in [json]'s `all`, and
     * disabled rather than left to open nothing once it does not.
     */
    fun publish(context: Context, json: String) {
        val o = JSONObject(json)
        val listed = parse(o.optJSONArray("listed") ?: JSONArray())
        val all = parse(o.optJSONArray("all") ?: JSONArray()).associateBy { PREFIX + it.id }
        val max = ShortcutManagerCompat.getMaxShortcutCountPerActivity(context)
        val dynamic = listed.take(max)
        ShortcutManagerCompat.setDynamicShortcuts(
            context,
            dynamic.mapIndexed { rank, e -> build(context, e, rank) },
        )
        val pinned = ShortcutManagerCompat.getShortcuts(context, ShortcutManagerCompat.FLAG_MATCH_PINNED)
            .map { it.id }
            .filter { it.startsWith(PREFIX) }
        val gone = pinned.filter { it !in all }
        if (gone.isNotEmpty()) {
            ShortcutManagerCompat.disableShortcuts(context, gone, context.getString(R.string.shortcut_server_gone))
        }
        // The ones `setDynamicShortcuts` did not already refresh: a server
        // back from a restore is enabled again, a renamed one relabelled.
        val dynamicIds = dynamic.map { PREFIX + it.id }.toSet()
        val rest = pinned.filter { it !in dynamicIds }.mapNotNull { all[it] }
        if (rest.isNotEmpty()) {
            val infos = rest.map { build(context, it, 0) }
            ShortcutManagerCompat.enableShortcuts(context, infos)
            ShortcutManagerCompat.updateShortcuts(context, infos)
        }
    }

    /** Asks the launcher to pin [entry]; false when it cannot. */
    fun requestPin(context: Context, entry: Entry): Boolean {
        if (!ShortcutManagerCompat.isRequestPinShortcutSupported(context)) return false
        return ShortcutManagerCompat.requestPinShortcut(context, build(context, entry, 0), null)
    }

    private fun parse(arr: JSONArray): List<Entry> {
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
