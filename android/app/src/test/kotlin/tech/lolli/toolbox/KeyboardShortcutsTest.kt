package tech.lolli.toolbox

import android.view.KeyEvent
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class KeyboardShortcutsTest {
    @Test
    fun readsKbChordGrammar() {
        assertEquals(
            KeyEvent.KEYCODE_BACKSLASH to (KeyEvent.META_CTRL_ON or KeyEvent.META_ALT_ON),
            KeyboardShortcuts.chord("Ctrl+Alt+\\"),
        )
        assertEquals(
            KeyEvent.KEYCODE_T to (KeyEvent.META_CTRL_ON or KeyEvent.META_ALT_ON or KeyEvent.META_SHIFT_ON),
            KeyboardShortcuts.chord("Ctrl+Alt+Shift+T"),
        )
        assertEquals(KeyEvent.KEYCODE_DPAD_LEFT to KeyEvent.META_META_ON, KeyboardShortcuts.chord("Meta+←"))
        assertEquals(KeyEvent.KEYCODE_1 to KeyEvent.META_CTRL_ON, KeyboardShortcuts.chord("Ctrl+1"))
        assertEquals(KeyEvent.KEYCODE_F12 to 0, KeyboardShortcuts.chord("F12"))
        assertEquals(KeyEvent.KEYCODE_ESCAPE to 0, KeyboardShortcuts.chord("Escape"))
    }

    @Test
    fun refusesWhatItCannotName() {
        assertNull(KeyboardShortcuts.chord(""))
        assertNull(KeyboardShortcuts.chord("Ctrl+1…9"))
        assertNull(KeyboardShortcuts.chord("Hyper+K"))
        assertNull(KeyboardShortcuts.chord("Ctrl+"))
    }
}
