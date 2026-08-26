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
     * The largest bitmap this will produce, in pixels per side.
     *
     * A 4x4 widget on a 3x-density screen is around 750px across, so this is
     * generous for the real case while bounding what a launcher reporting an
     * absurd size could ask for. At `ARGB_8888` a 900x900 bitmap is about
     * 3 MiB — already past what one `RemoteViews` should carry, which is why
     * the drawing is scaled to fit rather than to fill.
     */
    private const val MAX_SIDE = 900

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
        val w = widthPx.coerceIn(1, MAX_SIDE)
        val h = heightPx.coerceIn(1, MAX_SIDE)

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
