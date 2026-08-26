package tech.lolli.toolbox.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import org.json.JSONException
import tech.lolli.toolbox.R
import java.io.IOException
import java.net.SocketTimeoutException
import java.util.concurrent.ConcurrentHashMap
import kotlin.math.roundToInt

/**
 * The home-screen widget.
 *
 * Reads the agent's `/api/v1` endpoints with the scoped, read-only token the
 * app published — see `WidgetStore`. It used to fetch the unauthenticated
 * compat endpoint from a URL typed by hand into the configuration screen,
 * which answered preformatted strings and no history, so the widget could
 * never draw a trend and configuring it meant retyping an address the app
 * already knew (#951).
 *
 * An `AppWidgetProvider` is a `BroadcastReceiver` in the app's own process, so
 * everything it needs is readable without a channel hop — which is the thing
 * iOS needs a shared Keychain group to arrange.
 */
class HomeWidget : AppWidgetProvider() {
    companion object {
        private const val TAG = "HomeWidget"

        /**
         * Longer than the request timeout, so a slow answer still lands. A
         * broadcast receiver is not given long; overrunning means being killed
         * mid-update with the loading state left on screen.
         */
        private const val COROUTINE_TIMEOUT = 20_000L

        private val activeUpdates = ConcurrentHashMap<Int, Boolean>()
    }

    override fun onUpdate(context: Context, manager: AppWidgetManager, appWidgetIds: IntArray) {
        for (id in appWidgetIds) update(context, manager, id)
    }

    /**
     * Redrawn on resize, because size is what decides how many charts fit —
     * see [WidgetLayout.resolved]. Without this a widget dragged larger keeps
     * the single chart it was given at 2x2 until something else happens to
     * refresh it.
     */
    override fun onAppWidgetOptionsChanged(
        context: Context,
        manager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        update(context, manager, appWidgetId)
    }

    /** A widget dragged off the home screen must not leave its choices behind. */
    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        for (id in appWidgetIds) WidgetConfig.forget(context, id)
    }

    private fun update(context: Context, manager: AppWidgetManager, appWidgetId: Int) {
        // Two updates for one widget would race each other onto the screen,
        // and the loser's `updateAppWidget` is the one that sticks.
        if (activeUpdates.putIfAbsent(appWidgetId, true) == true) {
            Log.d(TAG, "Widget $appWidgetId is already updating, skipping")
            return
        }

        val views = RemoteViews(context.packageName, R.layout.home_widget)
        setupClickIntent(context, views, appWidgetId)

        val config = WidgetConfig.load(context, appWidgetId)
        val server = config.serverId.takeIf { it.isNotEmpty() }
            ?.let { WidgetStore.server(context, it) }
        if (server == null) {
            // Either nothing has been picked, or the server was deleted in the
            // app after this widget was pointed at it. Both are fixed in the
            // same place, which is where tapping the widget goes.
            showError(context, views, manager, appWidgetId, R.string.widget_err_not_configured)
            activeUpdates.remove(appWidgetId)
            return
        }

        showLoading(views, manager, appWidgetId, server.name)

        CoroutineScope(Dispatchers.IO).launch {
            withTimeoutOrNull(COROUTINE_TIMEOUT) {
                try {
                    val (reading, history) = WidgetApi.load(context, server)
                    val bounds = boundsOf(context, manager, appWidgetId)
                    withContext(Dispatchers.Main) {
                        showData(context, views, manager, appWidgetId, config, reading, history, bounds)
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "Widget $appWidgetId update failed: ${e.message}")
                    val message = when (e) {
                        is WidgetApi.MissingTokenException -> R.string.widget_err_no_token
                        is WidgetApi.InsecureException -> R.string.widget_err_insecure
                        is SocketTimeoutException -> R.string.widget_err_timeout
                        is JSONException -> R.string.widget_err_network
                        is IOException -> R.string.widget_err_network
                        else -> R.string.widget_err_network
                    }
                    withContext(Dispatchers.Main) {
                        showError(context, views, manager, appWidgetId, message, server.name)
                    }
                }
            } ?: run {
                Log.w(TAG, "Widget $appWidgetId update timed out")
                withContext(Dispatchers.Main) {
                    showError(context, views, manager, appWidgetId, R.string.widget_err_timeout, server.name)
                }
            }
            activeUpdates.remove(appWidgetId)
        }
    }

    /** The widget's size in grid cells and in pixels, as the launcher reports it. */
    private data class Bounds(val columns: Int, val rows: Int, val widthPx: Int, val heightPx: Int)

    private fun boundsOf(context: Context, manager: AppWidgetManager, appWidgetId: Int): Bounds {
        val options = manager.getAppWidgetOptions(appWidgetId)
        // The *minimum* of the range the launcher gives, which is the size the
        // widget is guaranteed. Using the maximum would draw a bitmap wider
        // than the view and let the scale type crop it.
        val widthDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 110)
            .takeIf { it > 0 } ?: 110
        val heightDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 110)
            .takeIf { it > 0 } ?: 110
        val density = context.resources.displayMetrics.density
        return Bounds(
            // The launcher's own cell arithmetic, near enough: a cell is
            // roughly 70dp wide with 30dp of margin between.
            columns = ((widthDp + 30) / 70).coerceAtLeast(1),
            rows = ((heightDp + 30) / 70).coerceAtLeast(1),
            widthPx = (widthDp * density).roundToInt(),
            // Only the part left after the header and any text rows.
            heightPx = (heightDp * density * 0.62f).roundToInt(),
        )
    }

    private fun setupClickIntent(context: Context, views: RemoteViews, appWidgetId: Int) {
        val intent = Intent(context, WidgetConfigureActivity::class.java).apply {
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            // Without this the reused activity keeps the first widget's extras
            // and every widget reconfigures the same one.
            data = android.net.Uri.parse("sbm://widget/$appWidgetId")
        }
        val flag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        views.setOnClickPendingIntent(
            R.id.widget_container,
            PendingIntent.getActivity(context, appWidgetId, intent, flag),
        )
    }

    // MARK: - States

    private fun showLoading(
        views: RemoteViews,
        manager: AppWidgetManager,
        appWidgetId: Int,
        name: String,
    ) {
        // The server's own name, not "Loading...": the name is already known
        // and is what identifies the widget among several on one screen.
        views.setTextViewText(R.id.widget_name, name)
        views.setViewVisibility(R.id.error_message, View.GONE)
        manager.updateAppWidget(appWidgetId, views)
    }

    private fun showData(
        context: Context,
        views: RemoteViews,
        manager: AppWidgetManager,
        appWidgetId: Int,
        config: WidgetConfig,
        reading: WidgetApi.Reading,
        history: List<WidgetApi.HistoryPoint>,
        bounds: Bounds,
    ) {
        views.setTextViewText(R.id.widget_name, reading.name)
        views.setTextViewText(
            R.id.widget_time,
            android.text.format.DateFormat.format("HH:mm", java.util.Date()).toString(),
        )
        views.setViewVisibility(R.id.error_message, View.GONE)

        val layout = config.layout.resolved(bounds.columns, bounds.rows)
        if (layout == WidgetLayout.TEXT) {
            views.setViewVisibility(R.id.widget_chart, View.GONE)
            views.setViewVisibility(R.id.widget_content, View.VISIBLE)
            showReadings(views, reading, compact = bounds.columns < 3)
        } else {
            val count = when (layout) {
                WidgetLayout.FOUR_CHARTS -> 4
                WidgetLayout.TWO_CHARTS -> 2
                else -> 1
            }
            val bitmap = WidgetChart.render(
                context = context,
                series = config.metric.following(count).map { seriesFor(context, it, reading, history) },
                widthPx = bounds.widthPx,
                heightPx = bounds.heightPx,
            )
            if (bitmap != null) {
                views.setImageViewBitmap(R.id.widget_chart, bitmap)
                views.setViewVisibility(R.id.widget_chart, View.VISIBLE)
                views.setViewVisibility(R.id.widget_content, View.GONE)
            } else {
                views.setViewVisibility(R.id.widget_chart, View.GONE)
                views.setViewVisibility(R.id.widget_content, View.VISIBLE)
                showReadings(views, reading, compact = bounds.columns < 3)
            }
        }
        manager.updateAppWidget(appWidgetId, views)
    }

    /**
     * Two rows on a widget the size of an app icon, four when there is room.
     *
     * Four labelled rows at 2x2 are legible only at a size nobody reads at
     * arm's length, so the small case gets the two that answer "is this
     * machine busy".
     */
    private fun showReadings(views: RemoteViews, reading: WidgetApi.Reading, compact: Boolean) {
        views.setTextViewText(R.id.widget_cpu, percentText(reading.cpu))
        views.setTextViewText(R.id.widget_mem, reading.memText)
        views.setTextViewText(R.id.widget_disk, reading.diskText)
        views.setTextViewText(R.id.widget_net, reading.netText)
        val rest = if (compact) View.GONE else View.VISIBLE
        views.setViewVisibility(R.id.widget_cpu_label, View.VISIBLE)
        views.setViewVisibility(R.id.widget_mem_label, View.VISIBLE)
        views.setViewVisibility(R.id.widget_disk_label, rest)
        views.setViewVisibility(R.id.widget_net_label, rest)
    }

    private fun showError(
        context: Context,
        views: RemoteViews,
        manager: AppWidgetManager,
        appWidgetId: Int,
        messageRes: Int,
        name: String? = null,
    ) {
        views.setTextViewText(R.id.widget_name, name ?: context.getString(R.string.app_name))
        views.setTextViewText(R.id.error_message, context.getString(messageRes))
        views.setViewVisibility(R.id.error_message, View.VISIBLE)
        views.setViewVisibility(R.id.widget_content, View.GONE)
        views.setViewVisibility(R.id.widget_chart, View.GONE)
        manager.updateAppWidget(appWidgetId, views)
    }

    // MARK: - Reading a metric

    private fun percentText(value: Double?): String =
        value?.let { String.format("%.0f%%", it) } ?: "--"

    private fun seriesFor(
        context: Context,
        metric: WidgetMetric,
        reading: WidgetApi.Reading,
        history: List<WidgetApi.HistoryPoint>,
    ): WidgetChart.Series = when (metric) {
        WidgetMetric.CPU -> WidgetChart.Series(
            label = context.getString(R.string.widget_metric_cpu),
            values = history.map { it.cpu },
            secondary = emptyList(),
            isPercent = true,
            valueText = percentText(reading.cpu),
            color = Color.parseColor("#34C759"),
        )
        WidgetMetric.MEMORY -> WidgetChart.Series(
            label = context.getString(R.string.widget_metric_memory),
            values = history.map { it.memory },
            secondary = emptyList(),
            isPercent = true,
            valueText = percentText(reading.mem),
            color = Color.parseColor("#0A84FF"),
        )
        WidgetMetric.DISK -> WidgetChart.Series(
            label = context.getString(R.string.widget_metric_disk),
            values = history.map { it.disk },
            secondary = emptyList(),
            isPercent = true,
            valueText = percentText(reading.disk),
            color = Color.parseColor("#FF9F0A"),
        )
        // A rate has no ceiling to be a percentage of, so the scale is drawn
        // from the data and the reading is shown as bytes.
        WidgetMetric.NETWORK -> WidgetChart.Series(
            label = context.getString(R.string.widget_metric_network),
            values = history.map { it.netRx },
            secondary = history.map { it.netTx },
            isPercent = false,
            valueText = reading.netText,
            color = Color.parseColor("#BF5AF2"),
        )
    }
}
