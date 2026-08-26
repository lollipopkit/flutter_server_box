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
        val color: Int,
    )

    /**
     * [widthPx] x [heightPx] of panels laid out to match [count].
     *
     * Returns null when there is nothing to draw, so the caller hides the
     * image rather than showing an empty box.
     */
    fun render(
        context: Context,
        series: List<Series>,
        widthPx: Int,
        heightPx: Int,
    ): Bitmap? {
        if (series.isEmpty()) return null
        val (w, h) = withinBudget(widthPx.coerceAtLeast(1), heightPx.coerceAtLeast(1))

        val columns = if (series.size >= 4) 2 else if (series.size == 2) 2 else 1
        val rows = if (series.size >= 4) 2 else 1

        val bitmap = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val gap = (min(w, h) * 0.03f).coerceIn(2f, 10f)
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
    private fun withinBudget(width: Int, height: Int): Pair<Int, Int> {
        val pixels = width.toLong() * height.toLong()
        if (pixels <= MAX_PIXELS) return width to height
        val scale = kotlin.math.sqrt(MAX_PIXELS.toDouble() / pixels.toDouble())
        return (width * scale).toInt().coerceAtLeast(1) to
            (height * scale).toInt().coerceAtLeast(1)
    }

    private fun drawPanel(
        context: Context,
        canvas: Canvas,
        series: Series,
        left: Float,
        top: Float,
        width: Float,
        height: Float,
    ) {
        val labelSize = (height * 0.17f).coerceIn(9f, 26f)
        val text = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            typeface = Typeface.MONOSPACE
            textSize = labelSize
            color = context.getColor(R.color.widgetSummaryText)
        }
        canvas.drawText(series.label, left, top + labelSize, text)

        val value = Paint(text).apply {
            typeface = Typeface.create(Typeface.MONOSPACE, Typeface.BOLD)
            color = context.getColor(R.color.widgetText)
            textAlign = Paint.Align.RIGHT
        }
        canvas.drawText(series.valueText, left + width, top + labelSize, value)

        val plotTop = top + labelSize * 1.5f
        val plotHeight = height - labelSize * 1.5f
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
