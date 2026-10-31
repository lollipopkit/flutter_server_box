package tech.lolli.toolbox.widget

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.Shader
import kotlin.math.max
import kotlin.math.sqrt

/**
 * Draws one trend as an alpha mask.
 *
 * A `RemoteViews` cannot hold a custom view, so a trend has to arrive as an
 * image. It is drawn in alpha only (`ALPHA_8`) and coloured by the
 * `ImageView`'s `android:tint`, which the launcher resolves: the colour then
 * follows the wallpaper and the light or dark theme without a redraw, and the
 * bitmap is a quarter of an `ARGB_8888` one. No text is drawn here — labels and
 * readings are `TextView`s, so nothing is stretched with the image.
 */
object WidgetChart {
    /**
     * The most bitmap one update may carry, in bytes (one per pixel), across
     * every trend at every size it is rendered at.
     *
     * The whole `RemoteViews` transaction has a hard limit of about a
     * megabyte, shared with the layouts; exceeding it throws
     * `TransactionTooLargeException` and the update never reaches the
     * launcher. The caller divides this between its trends ([render]'s
     * `maxPixels`); one drawn smaller is scaled up by the `ImageView`, which
     * costs a little softness.
     */
    const val BUDGET_PIXELS = 512 * 1024

    private const val STROKE_DP = 2.2f
    private const val SECONDARY_STROKE_DP = 1.4f

    /** Opacity of the fill under the line, at its top; it fades to nothing. */
    private const val FILL_ALPHA = 96
    private const val SECONDARY_ALPHA = 150

    /**
     * Ceilings for a percentage, the smallest that holds the data with room
     * to spare. A fixed 0..100 drew a 2% CPU as a flat line on the floor;
     * scaling to the data alone made noise look like load. The reading beside
     * the trend is what says how much.
     */
    private val PERCENT_CEILINGS = listOf(5.0, 10.0, 25.0, 50.0, 100.0)

    /**
     * [values] (and [secondary], thinner and unfilled, on the same scale) in
     * [widthPx] x [heightPx], or null when there are not two points to join.
     */
    fun render(
        values: List<Double>,
        secondary: List<Double>,
        isPercent: Boolean,
        widthPx: Int,
        heightPx: Int,
        density: Float,
        maxPixels: Int,
    ): Bitmap? {
        if (values.size < 2 || widthPx < 2 || heightPx < 2) return null
        val shrink = within(widthPx, heightPx, maxPixels)
        val w = (widthPx * shrink).toInt().coerceAtLeast(2)
        val h = (heightPx * shrink).toInt().coerceAtLeast(2)
        val px = density * shrink

        val peak = (values + secondary).maxOrNull() ?: 0.0
        val ceiling = if (isPercent) {
            PERCENT_CEILINGS.firstOrNull { peak * 1.2 <= it } ?: 100.0
        } else {
            max(peak * 1.15, 1.0)
        }

        val bitmap = Bitmap.createBitmap(w, h, Bitmap.Config.ALPHA_8)
        val canvas = Canvas(bitmap)
        val stroke = STROKE_DP * px
        // Inset by half a stroke, so the line is not clipped at the edges.
        val inset = stroke
        val plot = Plot(inset, inset, w - inset * 2, h - inset * 2, ceiling)

        val line = smooth(plot, values)
        val area = Path(line).apply {
            lineTo(plot.left + plot.width, plot.top + plot.height + inset)
            lineTo(plot.left, plot.top + plot.height + inset)
            close()
        }
        canvas.drawPath(area, Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
            shader = LinearGradient(
                0f, plot.top, 0f, h.toFloat(),
                Color.argb(FILL_ALPHA, 0, 0, 0), Color.argb(0, 0, 0, 0),
                Shader.TileMode.CLAMP,
            )
        })
        canvas.drawPath(line, strokePaint(stroke, 255))

        if (secondary.size >= 2) {
            canvas.drawPath(smooth(plot, secondary), strokePaint(SECONDARY_STROKE_DP * px, SECONDARY_ALPHA))
        }
        return bitmap
    }

    private class Plot(
        val left: Float,
        val top: Float,
        val width: Float,
        val height: Float,
        val ceiling: Double,
    ) {
        fun x(i: Int, count: Int) = left + width * i / (count - 1)
        fun y(v: Double) = top + height - (v.coerceIn(0.0, ceiling) / ceiling * height).toFloat()
    }

    /**
     * Through every point, with each corner rounded by a quadratic through the
     * midpoints: no overshoot past a reading, which a spline would add.
     */
    private fun smooth(plot: Plot, values: List<Double>): Path {
        val n = values.size
        val path = Path()
        var px = plot.x(0, n)
        var py = plot.y(values[0])
        path.moveTo(px, py)
        for (i in 1 until n) {
            val x = plot.x(i, n)
            val y = plot.y(values[i])
            path.quadTo(px, py, (px + x) / 2, (py + y) / 2)
            px = x
            py = y
        }
        path.lineTo(px, py)
        return path
    }

    private fun strokePaint(width: Float, alpha: Int) = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = width
        strokeCap = Paint.Cap.ROUND
        strokeJoin = Paint.Join.ROUND
        color = Color.argb(alpha, 0, 0, 0)
    }

    /** The factor that brings [w] x [h] within [maxPixels], keeping its shape. */
    private fun within(w: Int, h: Int, maxPixels: Int): Float {
        val pixels = w.toLong() * h.toLong()
        return if (pixels <= maxPixels) 1f else sqrt(maxPixels.toDouble() / pixels).toFloat()
    }
}
