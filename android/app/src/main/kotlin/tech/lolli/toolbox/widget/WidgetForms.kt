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
 * What a widget is about to show, as text: the room it takes is worked out
 * from this, so a network rate ("123.4k/s") or a German label asks for more
 * than "5%" and "CPU" do.
 */
class WidgetContent(
    val hero: String,
    /** What the hero is ("Disk"): the least its caption can say. */
    val label: String,
    /** [label] and its detail ("Disk · 48g / 100g"), shown where it fits. */
    val caption: String,
    /** The meters' labels and values (`widget_medium`'s bottom row). */
    val meterLabels: List<String>,
    val meterValues: List<String>,
    /** The one-row widget's side lines ("Memory 61%"). */
    val side: List<String>,
)

/**
 * The largest layout that fits a widget, and the boxes its trends get, worked
 * out from what each layout needs rather than from cell counts.
 *
 * The widget's real size comes from the launcher, so this follows the device,
 * its grid and its display-size setting by itself; what is computed here is
 * how much room each `widget_*` layout takes, from its own type sizes and
 * paddings, the text it is about to show, and the user's font scale. A widget
 * that does not have that room falls back to a smaller layout instead of
 * clipping. Keep the numbers in step with the layouts.
 */
object WidgetForms {
    /** A line of text takes about this much more than its size. */
    private const val LINE = 1.2f

    /** The smallest trend worth drawing, in dp. */
    private const val MIN_CHART_W = 100f
    private const val MIN_CHART_H = 40f
    private const val MIN_SECOND_CHART_H = 64f

    fun formFor(widthDp: Float, heightDp: Float, fontScale: Float, content: WidgetContent): WidgetForm {
        fun fits(stacked: Boolean, extraHeight: Float): Boolean {
            val n = Needs(fontScale, content, stacked)
            return widthDp >= n.mediumWidth && heightDp >= n.mediumHeight + extraHeight
        }
        val n = Needs(fontScale, content, stacked = false)
        val secondTrend = n.secondFixed + MIN_SECOND_CHART_H
        return when {
            fits(false, secondTrend) || fits(true, secondTrend) -> WidgetForm.LARGE
            fits(false, 0f) || fits(true, 0f) -> WidgetForm.MEDIUM
            widthDp >= n.smallWidth && heightDp >= n.smallHeight -> WidgetForm.SMALL
            else -> WidgetForm.TINY
        }
    }

    /**
     * Whether the meters must put a two-part value ("↓1.2m ↑340k") on two
     * lines to fit three across [widthDp]: one line where it fits, since it
     * keeps the row shorter.
     */
    fun metersStacked(widthDp: Float, fontScale: Float, content: WidgetContent): Boolean =
        widthDp < Needs(fontScale, content, stacked = false).mediumWidth

    /** What a one-row widget shows beside its reading. */
    enum class TinyCaption { NONE, LABEL, FULL }

    class TinyFit(val caption: TinyCaption, val side: Boolean)

    /**
     * What fits in a one-row widget [widthDp] wide, most telling first: the
     * label, then the side lines, then the caption's detail.
     */
    fun tiny(widthDp: Float, fontScale: Float, content: WidgetContent): TinyFit {
        val n = Needs(fontScale, content, stacked = false)
        if (widthDp < n.tinyLeft) return TinyFit(TinyCaption.NONE, side = false)
        val side = widthDp >= n.tinyLeft + n.tinySide
        val full = widthDp >= n.tinyCaptionWidth + (if (side) n.tinySide else 0f)
        return TinyFit(if (full) TinyCaption.FULL else TinyCaption.LABEL, side)
    }

    /** The leading trend's box in dp, in `widget_medium` or `widget_large`. */
    fun heroChartBox(form: WidgetForm, widthDp: Float, heightDp: Float, fontScale: Float, content: WidgetContent): Pair<Float, Float> {
        val n = Needs(fontScale, content, metersStacked(widthDp, fontScale, content))
        val w = widthDp - 32f - n.heroWidth - 14f
        val body = heightDp - n.chrome
        val row = if (form == WidgetForm.LARGE) (body - n.secondFixed) / 2f else body
        return w.coerceAtLeast(24f) to (row - 12f).coerceAtLeast(16f)
    }

    /** The second trend's box in dp, in `widget_large`. */
    fun secondChartBox(widthDp: Float, heightDp: Float, fontScale: Float, content: WidgetContent): Pair<Float, Float> {
        val n = Needs(fontScale, content, metersStacked(widthDp, fontScale, content))
        val body = heightDp - n.chrome
        return (widthDp - 32f).coerceAtLeast(24f) to ((body - n.secondFixed) / 2f).coerceAtLeast(16f)
    }

    /**
     * How wide [text] is at [sp], in dp: about half an em for Latin digits
     * and letters, a whole one for CJK.
     */
    fun width(text: String, sp: Float, fontScale: Float): Float =
        text.sumOf {
            when {
                it.code in 0x2066..0x2069 -> 0.0 // bidi isolates, invisible
                it.code >= 0x2E80 -> 1.0
                else -> 0.56
            }
        }.toFloat() * sp * fontScale

    /**
     * Sizes in dp, from the layouts' sp at [fontScale] and [content]; with the
     * meters' two-part values on two lines when [stacked].
     */
    private class Needs(val fontScale: Float, val content: WidgetContent, val stacked: Boolean) {
        fun line(sp: Float) = sp * fontScale * LINE
        fun w(text: String, sp: Float) = width(text, sp, fontScale)
        fun widest(texts: List<String>, sp: Float) = texts.maxOfOrNull { w(it, sp) } ?: 0f

        // Header: 24dp of refresh button, or the name if the font is larger.
        private val header = max(24f, line(14f))

        // A meter's value, as it is laid out: split at the space when stacked.
        private val meterValueLines = content.meterValues.map { if (stacked) it.split(' ') else listOf(it) }

        // Meters row: label, value (one or two lines), gap and bar (`widget_medium`).
        private val meters = line(11f) + line(14f) * (meterValueLines.maxOfOrNull { it.size } ?: 1) + 4f + 5f

        /** Everything in `widget_medium` that is not the hero row. */
        val chrome = 28f + header + 4f + meters

        /** `widget_large`'s second trend, less its chart: margin, header, gap. */
        val secondFixed = 12f + line(12f) + 6f

        val smallHeight = 28f + max(24f, line(13f)) + 40f * fontScale + 2f + line(12f) +
            2 * (line(11f) + 3f + 5f)
        val smallWidth = 28f + max(w(content.hero, 40f), w(content.label, 12f))

        // Hero column: 52sp without font padding, then its label (a longer
        // caption is ellipsized); at least `widget_medium`'s minWidth.
        val heroWidth = max(84f, max(w(content.hero, 52f), w(content.label, 12f)))
        private val heroColumn = 52f * fontScale + 2f + line(12f)

        val mediumHeight = chrome + max(heroColumn, MIN_CHART_H + 12f)

        // The hero beside a trend, and three meters side by side.
        private val meterWidth = max(widest(content.meterLabels, 11f), widest(meterValueLines.flatten(), 14f))
        val mediumWidth = max(32f + heroWidth + 14f + MIN_CHART_W, 32f + 3 * meterWidth + 2 * 14f)


        // Name or the reading and its caption on the left, the side lines on
        // the right (`widget_tiny`).
        val tinyLeft = 32f + w(content.hero, 28f) + 6f + w(content.label, 12f)
        val tinyCaptionWidth = 32f + w(content.hero, 28f) + 6f + w(content.caption, 12f)
        val tinySide = 12f + widest(content.side, 12f)
    }
}
