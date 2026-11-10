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

    private val cpu = WidgetContent(
        hero = "23%",
        label = "CPU",
        caption = "CPU",
        meterLabels = listOf("Memory", "Disk", "Network"),
        meterValues = listOf("61%", "48%", "↓1.2m ↑340k"),
        side = listOf("Memory 61%", "Disk 48%"),
    )

    private val network = WidgetContent(
        hero = "123k/s",
        label = "Network",
        caption = "Network · ↑ 340k/s",
        meterLabels = listOf("CPU", "Memory", "Disk"),
        meterValues = listOf("23%", "61%", "48%"),
        side = listOf("CPU 23%", "Memory 61%"),
    )

    private val german = WidgetContent(
        hero = "23%",
        label = "CPU",
        caption = "CPU",
        meterLabels = listOf("Arbeitsspeicher", "Datenträger", "Netzwerk"),
        meterValues = listOf("61%", "48%", "↓1.2m ↑340k"),
        side = listOf("Arbeitsspeicher 61%", "Datenträger 48%"),
    )

    private fun form(size: Pair<Float, Float>, content: WidgetContent = cpu, fontScale: Float = 1f) =
        WidgetForms.formFor(size.first, size.second, fontScale, content)

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
        // Three meters do not fit 300dp on one line each: the network value
        // goes on two, and the row is taller for it.
        assertTrue(WidgetForms.metersStacked(300f, 1f, cpu))
        assertFalse(WidgetForms.metersStacked(pixel4x2.first, 1f, cpu))
        assertEquals(WidgetForm.MEDIUM, form(300f to 200f))
        assertEquals(WidgetForm.TINY, form(300f to 140f))
    }

    @Test
    fun `a larger font falls back to a more compact layout`() {
        assertEquals(WidgetForm.MEDIUM, form(300f to 200f, fontScale = 1f))
        assertEquals(WidgetForm.SMALL, form(300f to 200f, fontScale = 1.3f))
        assertEquals(WidgetForm.TINY, form(300f to 170f, fontScale = 1.3f))
    }

    @Test
    fun `a wider reading asks for more room than a percentage`() {
        // "123k/s" at 52sp leaves no room for a trend beside it at 260dp.
        assertEquals(WidgetForm.MEDIUM, form(260f to 250f, cpu))
        assertEquals(WidgetForm.SMALL, form(260f to 250f, network))
    }

    @Test
    fun `a narrow widget does not get a layout whose reading it cannot hold`() {
        val full = WidgetContent("100%", "CPU", "CPU", cpu.meterLabels, cpu.meterValues, cpu.side)
        assertEquals(WidgetForm.SMALL, form(110f to 250f, cpu))
        assertEquals(WidgetForm.TINY, form(110f to 250f, full))
    }

    @Test
    fun `a one-row widget sheds detail, then side lines, then its label`() {
        val wide = WidgetForms.tiny(pixel4x1.first, 1f, cpu)
        assertTrue(wide.side)
        assertEquals(WidgetForms.TinyCaption.FULL, wide.caption)

        val narrow = WidgetForms.tiny(pixel2x1.first, 1f, network)
        assertFalse(narrow.side)

        assertEquals(WidgetForms.TinyCaption.NONE, WidgetForms.tiny(110f, 1f, network).caption)
    }

    @Test
    fun `long translated labels need more room than short ones`() {
        assertTrue(WidgetForms.tiny(pixel4x1.first, 1f, cpu).side)
        assertTrue(WidgetForms.tiny(240f, 1f, cpu).side)
        assertFalse(WidgetForms.tiny(240f, 1f, german).side)
    }
}
