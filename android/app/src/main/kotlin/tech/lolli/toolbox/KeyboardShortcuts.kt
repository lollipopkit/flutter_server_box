package tech.lolli.toolbox

import android.view.KeyEvent
import android.view.KeyboardShortcutGroup
import android.view.KeyboardShortcutInfo
import org.json.JSONArray

/**
 * The app's keys in the system's shortcut list (Meta+/ on a hardware
 * keyboard), as bound on the shortcuts page — pushed from Dart whenever they
 * change, since a user can rebind them.
 */
object KeyboardShortcuts {
    class Item(val label: String, val keyCode: Int, val meta: Int)
    class Group(val label: String, val items: List<Item>)

    /** `[{"label","items":[{"label","chord"}]}]`; a chord this cannot express is left out. */
    fun parse(json: String): List<Group> {
        val arr = JSONArray(json)
        return (0 until arr.length()).mapNotNull { i ->
            val g = arr.optJSONObject(i) ?: return@mapNotNull null
            val items = g.optJSONArray("items") ?: JSONArray()
            val parsed = (0 until items.length()).mapNotNull { j ->
                val it = items.optJSONObject(j) ?: return@mapNotNull null
                val (code, meta) = chord(it.optString("chord")) ?: return@mapNotNull null
                Item(it.optString("label"), code, meta)
            }
            if (parsed.isEmpty()) null else Group(g.optString("label"), parsed)
        }
    }

    fun toSystem(groups: List<Group>): List<KeyboardShortcutGroup> = groups.map { g ->
        KeyboardShortcutGroup(g.label, g.items.map { KeyboardShortcutInfo(it.label, it.keyCode, it.meta) })
    }

    /**
     * `KbChord`'s grammar: `Ctrl`, `Meta`, `Alt`, `Shift`, then one key —
     * letters, digits, punctuation as itself, arrows as `←→↑↓`, named keys.
     */
    fun chord(chord: String): Pair<Int, Int>? {
        if (chord.isEmpty()) return null
        val parts = chord.split('+')
        val code = KEYS[parts.last()] ?: return null
        var meta = 0
        for (m in parts.dropLast(1)) {
            meta = meta or when (m) {
                "Ctrl" -> KeyEvent.META_CTRL_ON
                "Meta" -> KeyEvent.META_META_ON
                "Alt" -> KeyEvent.META_ALT_ON
                "Shift" -> KeyEvent.META_SHIFT_ON
                else -> return null
            }
        }
        return code to meta
    }

    private val KEYS: Map<String, Int> = buildMap {
        for (c in 0 until 26) put(('A' + c).toString(), KeyEvent.KEYCODE_A + c)
        for (d in 0..9) put(d.toString(), KeyEvent.KEYCODE_0 + d)
        for (f in 1..12) put("F$f", KeyEvent.KEYCODE_F1 + f - 1)
        put("\\", KeyEvent.KEYCODE_BACKSLASH)
        put("-", KeyEvent.KEYCODE_MINUS)
        put("=", KeyEvent.KEYCODE_EQUALS)
        put("[", KeyEvent.KEYCODE_LEFT_BRACKET)
        put("]", KeyEvent.KEYCODE_RIGHT_BRACKET)
        put(",", KeyEvent.KEYCODE_COMMA)
        put(".", KeyEvent.KEYCODE_PERIOD)
        put("/", KeyEvent.KEYCODE_SLASH)
        put(";", KeyEvent.KEYCODE_SEMICOLON)
        put("'", KeyEvent.KEYCODE_APOSTROPHE)
        put("`", KeyEvent.KEYCODE_GRAVE)
        put("←", KeyEvent.KEYCODE_DPAD_LEFT)
        put("→", KeyEvent.KEYCODE_DPAD_RIGHT)
        put("↑", KeyEvent.KEYCODE_DPAD_UP)
        put("↓", KeyEvent.KEYCODE_DPAD_DOWN)
        put("Space", KeyEvent.KEYCODE_SPACE)
        put("Tab", KeyEvent.KEYCODE_TAB)
        put("Escape", KeyEvent.KEYCODE_ESCAPE)
        put("Enter", KeyEvent.KEYCODE_ENTER)
        put("Backspace", KeyEvent.KEYCODE_DEL)
        put("Delete", KeyEvent.KEYCODE_FORWARD_DEL)
        put("PageUp", KeyEvent.KEYCODE_PAGE_UP)
        put("PageDown", KeyEvent.KEYCODE_PAGE_DOWN)
        put("Home", KeyEvent.KEYCODE_MOVE_HOME)
        put("End", KeyEvent.KEYCODE_MOVE_END)
    }
}
