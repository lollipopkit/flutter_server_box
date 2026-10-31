package tech.lolli.toolbox.widget

import kotlin.math.max

/** Which layout a widget gets. */
enum class WidgetForm {
    /** One row: name, the leading reading, two more as text when wide enough. */
    TINY,

    /** Narrow: the leading reading large, two meters. */
    SMALL,

    /** Wide: the leading reading beside its trend, three meters. */
    MEDIUM,

    /** Wide and tall: `MEDIUM` and a second trend. */
    LARGE,
}

/**
 * The largest layout that fits a widget, worked out from what each layout
 * needs rather than from cell counts.
 *
 * The widget's real size comes from the launcher, so this follows the device,
 * its grid and its display-size setting by itself; what is computed here is
 * how much room each `widget_*` layout takes, from its own type sizes and
 * paddings scaled by the user's font size. A larger font asks for more room,
 * and a widget that no longer has it falls back to a smaller layout instead
 * of clipping. Keep the numbers in step with the layouts.
 */
object WidgetForms {
    /** A line of text takes about this much more than its size. */
    private const val LINE = 1.2f

    /** Average advance of a digit or symbol, relative to the type size. */
    private const val GLYPH = 0.56f

    /** The smallest trend worth drawing, in dp. */
    private const val MIN_CHART_W = 60f
    private const val MIN_CHART_H = 40f
    private const val MIN_SECOND_CHART_H = 64f

    fun formFor(widthDp: Float, heightDp: Float, fontScale: Float): WidgetForm {
        val n = Needs(fontScale)
        return when {
            widthDp >= n.mediumWidth && heightDp >= n.largeHeight -> WidgetForm.LARGE
            widthDp >= n.mediumWidth && heightDp >= n.mediumHeight -> WidgetForm.MEDIUM
            heightDp >= n.smallHeight -> WidgetForm.SMALL
            else -> WidgetForm.TINY
        }
    }

    /** Whether a one-row widget has room for its two side readings. */
    fun tinyFitsSide(widthDp: Float, fontScale: Float): Boolean = widthDp >= Needs(fontScale).tinySideWidth

    /** Whether a one-row widget can follow its reading with the detail ("4.9g / 8.0g"). */
    fun tinyFitsDetail(widthDp: Float, fontScale: Float): Boolean = widthDp >= Needs(fontScale).tinyDetailWidth

    /** Sizes in dp, from the layouts' sp at [fontScale]. */
    private class Needs(val fontScale: Float) {
        fun line(sp: Float) = sp * fontScale * LINE
        fun digits(sp: Float, count: Int) = sp * fontScale * GLYPH * count

        // Header: 24dp of refresh button, or the name if the font is larger.
        private val header = max(24f, line(14f))

        // Meters row: label, value, gap and bar (`widget_medium`).
        private val meters = line(11f) + line(14f) + 4f + 5f

        val smallHeight = 28f + max(24f, line(13f)) + 40f * fontScale + 2f + line(12f) +
            2 * (line(11f) + 3f + 5f)

        // Hero column: 52sp without font padding, then its caption.
        private val heroColumn = 52f * fontScale + 2f + line(12f)

        val mediumHeight = 28f + header + 4f + max(heroColumn, MIN_CHART_H + 12f) + meters

        // "100%" beside a trend, or three meters of about nine glyphs each.
        val mediumWidth = max(
            32f + digits(52f, 4) + 14f + MIN_CHART_W,
            32f + 3 * digits(14f, 9) + 2 * 14f,
        )

        val largeHeight = mediumHeight + 12f + line(12f) + 6f + MIN_SECOND_CHART_H

        // Name or "100%" and its label on the left, "Memory 100%" on the right.
        private val tinyLeft = 32f + digits(28f, 4) + 6f + digits(12f, 4)
        val tinySideWidth = tinyLeft + 12f + digits(12f, 11)
        val tinyDetailWidth = tinyLeft + digits(12f, 14)
    }
}
