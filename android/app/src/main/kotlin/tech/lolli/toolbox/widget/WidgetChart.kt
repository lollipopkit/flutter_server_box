package tech.lolli.toolbox.widget

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.Typeface
import tech.lolli.toolbox.R
import kotlin.math.max
import kotlin.math.min

/**
 * Draws every chart panel into one bitmap.
 *
 * A `RemoteViews` cannot hold a custom view, so a trend line has to arrive as
 * an image. One image rather than one per panel: each bitmap crosses the
 * binder as part of the update, and the transaction has a hard size limit that
 * a widget cannot recover from — it simply stops updating, with a
 * `TransactionTooLargeException` in the log and nothing on screen to say so.
 *
 * The bitmap is sized from the space the launcher actually gave the widget
 * ([Bounds]), capped, and drawn at `ARGB_8888` because a gradient fill bands
 * visibly at anything less.
 */
object WidgetChart {
    /**
     * The most bitmap one update may carry, in bytes.
     *
     * The binding constraint is not a side length, it is the size of the whole
     * `RemoteViews` transaction — around a megabyte, shared with the layout
     * and with whatever else is in flight, and exceeding it throws
     * `TransactionTooLargeException` and stops the update reaching the
     * launcher at all. A per-side cap does not bound that: 900x900 at
     * `ARGB_8888` is 3.2 MiB, and even a 4x4 widget at 3x density
     * (about 750x465 after the header) is 1.4 MiB.
     *
     * So the budget is on area, and an image over it is drawn smaller and
     * stretched by the `ImageView` (`scaleType="fitXY"`). These are
     * antialiased line charts; a modest upscale costs a little softness, and a
     * widget that silently stops updating costs everything.
     */
    private const val MAX_BITMAP_BYTES = 640 * 1024

    /** `ARGB_8888`, chosen because a translucent fill bands visibly below it. */
    private const val BYTES_PER_PIXEL = 4

    private const val MAX_PIXELS = MAX_BITMAP_BYTES / BYTES_PER_PIXEL

    data class Series(
        val label: String,
        val values: List<Double>,
        /** Drawn beside [values] with no fill — the outbound half of network. */
        val secondary: List<Double>,
        /** Whether the vertical scale is a fixed 0..100. */
        val isPercent: Boolean,
        val valueText: String,
        /**
         * A shorter spelling of [valueText] for a panel too narrow for it.
         *
         * Only network has one worth having: its reading is two byte counts,
         * and on a one-column widget even the label-less full form is wider
         * than the panel. Everything else passes its own text through.
         */
        val valueShort: String,
        val color: Int,
    )

    /**
     * [widthPx] x [heightPx] of panels laid out to match [count].
     *
     * Returns null when there is nothing to draw, so the caller hides the
     * image rather than showing an empty box.
     */
    /** Between panels, in dp. Wide enough that a right-aligned value and the
     *  next panel's label cannot run together, which at 3% of the smaller side
     *  they did. */
    private const val GAP_DP = 10f

    /** Label and value type sizes, in dp. */
    private const val LABEL_DP = 11f
    private const val VALUE_DP = 15f

    /** Kept clear between a panel's label and its value. */
    private const val LABEL_GAP_DP = 10f

    /** How small the value may get, relative to the label, before the label is
     *  dropped instead. A panel has room for one of them at that point, and the
     *  number is the one worth reading — the colour already says which metric
     *  it is. */
    private const val MIN_VALUE_RATIO = 1.0f

    fun render(
        context: Context,
        series: List<Series>,
        widthPx: Int,
        heightPx: Int,
        density: Float,
    ): Bitmap? {
        if (series.isEmpty()) return null
        // The scale comes back too, because everything drawn is sized in dp:
        // shrinking the bitmap for the transaction budget has to shrink the
        // type with it, or the text would be over-large once the `ImageView`
        // scales the image back up.
        val (w, h, scale) = withinBudget(
            widthPx.coerceAtLeast(1),
            heightPx.coerceAtLeast(1),
        )
        val px = density * scale

        val columns = if (series.size >= 4) 2 else if (series.size == 2) 2 else 1
        val rows = if (series.size >= 4) 2 else 1

        val bitmap = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val gap = GAP_DP * px
        val cellW = (w - gap * (columns - 1)) / columns
        val cellH = (h - gap * (rows - 1)) / rows

        series.take(columns * rows).forEachIndexed { index, s ->
            val col = index % columns
            val row = index / columns
            drawPanel(
                context = context,
                canvas = canvas,
                series = s,
                left = col * (cellW + gap),
                top = row * (cellH + gap),
                width = cellW,
                height = cellH,
                px = px,
            )
        }
        return bitmap
    }

    /**
     * [width] x [height] shrunk to fit [MAX_PIXELS], keeping its shape.
     *
     * Proportional rather than clamped per side: the aspect ratio is what the
     * `ImageView` will stretch back to, and squashing one side alone would
     * make every chart lean.
     */
    private data class Sized(val width: Int, val height: Int, val scale: Float)

    private fun withinBudget(width: Int, height: Int): Sized {
        val pixels = width.toLong() * height.toLong()
        if (pixels <= MAX_PIXELS) return Sized(width, height, 1f)
        val scale = kotlin.math.sqrt(MAX_PIXELS.toDouble() / pixels.toDouble())
        return Sized(
            (width * scale).toInt().coerceAtLeast(1),
            (height * scale).toInt().coerceAtLeast(1),
            scale.toFloat(),
        )
    }

    private fun drawPanel(
        context: Context,
        canvas: Canvas,
        series: Series,
        left: Float,
        top: Float,
        width: Float,
        height: Float,
        px: Float,
    ) {
        // Sized in dp, not as a fraction of the panel. A fraction made the type
        // depend on the widget's shape — a tall 2x2 got huge letters, a wide
        // one got tiny ones — and on how far the bitmap had been scaled.
        // Capped by the panel so a very short one does not overflow its own
        // label row.
        val labelSize = (LABEL_DP * px).coerceAtMost(height * 0.22f)
        val text = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            typeface = Typeface.MONOSPACE
            textSize = labelSize
            color = context.getColor(R.color.widgetSummaryText)
        }

        val value = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            typeface = Typeface.create(Typeface.MONOSPACE, Typeface.BOLD)
            textSize = (VALUE_DP * px).coerceAtMost(height * 0.28f)
            color = context.getColor(R.color.widgetText)
            textAlign = Paint.Align.RIGHT
        }

        // Shrunk to what is left after the label, rather than drawn at a fixed
        // size and allowed to run into it. Network is the case that forces
        // this: its reading is two byte counts ("92.9m / 71.2m"), which in a
        // four-panel grid is wider than the panel itself — and a right-aligned
        // string that does not fit grows leftwards, straight through the label.
        val full = value.textSize
        val floor = labelSize * MIN_VALUE_RATIO
        val beside = width - text.measureText(series.label) - LABEL_GAP_DP * px

        // The size at which [str] exactly fills [avail], unclamped — so what
        // follows is decided by measuring rather than by guessing how wide a
        // string will be. Guessing is what the first attempt at this did, and
        // it kept the label on a panel that had no room for it.
        fun sizeFor(str: String, avail: Float): Float {
            value.textSize = full
            val needed = value.measureText(str)
            return if (needed <= avail || needed <= 0f) full else full * (avail / needed)
        }

        // In order of what is worth keeping: the label and the full reading,
        // then the label with a shorter one, then the reading alone. A
        // right-aligned string that does not fit grows leftwards — through the
        // label, and then out of the panel — so something has to give, and it
        // should be the least informative thing first.
        val options = listOf(
            Triple(true, series.valueText, beside),
            Triple(true, series.valueShort, beside),
            Triple(false, series.valueText, width),
            Triple(false, series.valueShort, width),
        )
        var showLabel = false
        var shown = series.valueShort
        var size = sizeFor(series.valueShort, width)
        for ((withLabel, str, avail) in options) {
            val fitted = sizeFor(str, avail)
            if (fitted >= floor) {
                showLabel = withLabel
                shown = str
                size = fitted
                break
            }
        }
        // Never clamped back up: a value that overflows its panel and runs into
        // the one beside it is worse than a small one.
        value.textSize = size

        val valueSize = value.textSize
        // Right-aligned to the panel, not to the bitmap: with four panels the
        // value of the left one and the label of the right one share a line,
        // and the gap between the cells is what keeps them apart.
        val baseline = top + maxOf(labelSize, valueSize)
        if (showLabel) canvas.drawText(series.label, left, baseline, text)
        canvas.drawText(shown, left + width, baseline, value)

        val plotTop = baseline + valueSize * 0.4f
        val plotHeight = height - (plotTop - top)
        if (plotHeight <= 2f) return

        if (series.values.isEmpty() && series.secondary.isEmpty()) {
            val hint = Paint(text).apply {
                textAlign = Paint.Align.CENTER
                alpha = 140
            }
            canvas.drawText(
                context.getString(R.string.widget_no_history),
                left + width / 2,
                plotTop + plotHeight / 2 + labelSize / 3,
                hint,
            )
            return
        }

        // Both series share one scale so the two lines are comparable. Reading
        // them against separate maxima would make a quiet upload look like a
        // busy one.
        val all = series.values + series.secondary
        val maxValue = if (series.isPercent) 100.0 else max(all.maxOrNull() ?: 1.0, 1.0)

        drawLine(canvas, series.values, left, plotTop, width, plotHeight, maxValue, series.color, fill = true)
        drawLine(canvas, series.secondary, left, plotTop, width, plotHeight, maxValue, series.color, fill = false)
    }

    private fun drawLine(
        canvas: Canvas,
        values: List<Double>,
        left: Float,
        top: Float,
        width: Float,
        height: Float,
        maxValue: Double,
        color: Int,
        fill: Boolean,
    ) {
        if (values.size < 2) return
        val stepX = width / (values.size - 1)
        fun y(v: Double) = top + height - (v.coerceIn(0.0, maxValue) / maxValue * height).toFloat()

        val path = Path().apply {
            moveTo(left, y(values[0]))
            values.forEachIndexed { i, v -> if (i > 0) lineTo(left + stepX * i, y(v)) }
        }

        if (fill) {
            val area = Path(path).apply {
                lineTo(left + width, top + height)
                lineTo(left, top + height)
                close()
            }
            canvas.drawPath(area, Paint(Paint.ANTI_ALIAS_FLAG).apply {
                style = Paint.Style.FILL
                this.color = Color.argb(56, Color.red(color), Color.green(color), Color.blue(color))
            })
        }

        canvas.drawPath(path, Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = (height * 0.035f).coerceIn(1.5f, 4f)
            strokeCap = Paint.Cap.ROUND
            strokeJoin = Paint.Join.ROUND
            this.color = if (fill) color else Color.argb(150, Color.red(color), Color.green(color), Color.blue(color))
        })
    }
}
