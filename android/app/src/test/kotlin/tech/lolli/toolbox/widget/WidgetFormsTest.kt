package tech.lolli.toolbox.widget

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class WidgetFormsTest {
    // Sizes a Pixel 8a launcher reported, in dp (portrait).
    private val pixel4x1 = 441f to 118f
    private val pixel2x1 = 212f to 118f
    private val pixel2x2 = 212f to 250f
    private val pixel4x2 = 441f to 250f
    private val pixel4x3 = 441f to 380f

    private fun form(size: Pair<Float, Float>, fontScale: Float = 1f) =
        WidgetForms.formFor(size.first, size.second, fontScale)

    @Test
    fun `each size gets the largest layout that fits it`() {
        assertEquals(WidgetForm.TINY, form(pixel4x1))
        assertEquals(WidgetForm.TINY, form(pixel2x1))
        assertEquals(WidgetForm.SMALL, form(pixel2x2))
        assertEquals(WidgetForm.MEDIUM, form(pixel4x2))
        assertEquals(WidgetForm.LARGE, form(pixel4x3))
    }

    @Test
    fun `a smaller grid still gets a layout that fits rather than clips`() {
        // A 4x2 on a denser grid.
        assertEquals(WidgetForm.MEDIUM, form(300f to 170f))
        // Too short for the hero column and meters.
        assertEquals(WidgetForm.TINY, form(300f to 140f))
    }

    @Test
    fun `a larger font falls back to a more compact layout`() {
        assertEquals(WidgetForm.MEDIUM, form(pixel4x2, fontScale = 1f))
        assertEquals(WidgetForm.SMALL, form(300f to 250f, fontScale = 1.3f))
        assertEquals(WidgetForm.TINY, form(300f to 170f, fontScale = 1.3f))
    }

    @Test
    fun `a one-row widget shows its side readings only when wide enough`() {
        assertTrue(WidgetForms.tinyFitsSide(pixel4x1.first, 1f))
        assertFalse(WidgetForms.tinyFitsSide(150f, 1f))
        assertTrue(WidgetForms.tinyFitsDetail(pixel4x1.first, 1f))
        assertFalse(WidgetForms.tinyFitsDetail(pixel2x1.first, 1.3f))
    }
}
