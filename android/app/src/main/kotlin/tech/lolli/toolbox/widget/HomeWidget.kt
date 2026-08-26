package tech.lolli.toolbox.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.util.TypedValue
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
abstract class HomeWidget(private val kind: WidgetKind) : AppWidgetProvider() {
    companion object {
        /** Both providers, for the callers that mean "every widget". */
        val providers = listOf(StatusWidgetSmall::class.java, StatusWidgetMedium::class.java)

        /** Asks every placed widget of either size to refresh. */
        fun broadcastUpdate(context: Context) {
            for (provider in providers) {
                context.sendBroadcast(
                    Intent(context, provider).apply {
                        action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                        putExtra(
                            AppWidgetManager.EXTRA_APPWIDGET_IDS,
                            AppWidgetManager.getInstance(context)
                                .getAppWidgetIds(ComponentName(context, provider)),
                        )
                    }
                )
            }
        }

        /** Which widget an id belongs to, or null when the system has forgotten it. */
        fun kindOf(context: Context, appWidgetId: Int): WidgetKind? {
            val provider = AppWidgetManager.getInstance(context)
                .getAppWidgetInfo(appWidgetId)?.provider?.className ?: return null
            return when (provider) {
                StatusWidgetSmall::class.java.name -> WidgetKind.SMALL
                StatusWidgetMedium::class.java.name -> WidgetKind.MEDIUM
                else -> null
            }
        }

        private const val TAG = "HomeWidget"

        /**
         * Longer than the request timeout, so a slow answer still lands. A
         * broadcast receiver is not given long; overrunning means being killed
         * mid-update with the loading state left on screen.
         */
        private const val COROUTINE_TIMEOUT = 20_000L

        private val activeUpdates = ConcurrentHashMap<Int, Boolean>()

        /**
         * What `home_widget.xml` takes before the chart gets any room, in dp.
         *
         * Read off that file and has to stay in step with it. Nothing here can
         * measure the `ImageView` — a `RemoteViews` is a description, not a
         * view tree — so the chart's box is the reported size minus this.
         * Being a little out only costs a margin now that the image scales
         * uniformly; it used to be the whole distortion, because the two axes
         * were out by different amounts and `fitXY` turned that into a
         * stretch.
         */
        /**
         * The chrome around the content, per widget rather than per cell count.
         *
         * It used to be decided by how many cells the launcher reported, which
         * was a guess standing in for a question now answered outright: the two
         * widgets are fixed sizes and each knows what it draws. The readings
         * one can afford room around its text — that is most of what iOS's
         * container margins buy it — while the chart one spends the same space
         * on the charts, which is the whole reason to choose it.
         */
        private const val CHART_PADDING_DP = 10f
        private const val CHART_MARGIN_DP = 6f
        private const val CHART_HEADER_SP = 14f

        private const val READINGS_PADDING_DP = 14f
        private const val READINGS_CHART_MARGIN_DP = 6f
        private const val READINGS_HEADER_SP = 13f

        /** The time, on its own line at the bottom. */
        private const val FOOTER_DP = 13f

        /** A single line of text takes about this much more than its size. */
        private const val HEADER_LINE_RATIO = 1.45f
    }

    override fun onUpdate(context: Context, manager: AppWidgetManager, appWidgetIds: IntArray) {
        for (id in appWidgetIds) update(context, manager, id)
    }

    /**
     * Neither widget resizes, but a launcher may still report a different box
     * for one — a home screen with a different grid, or a fold opening. The
     * bitmap is drawn to that box, so it has to be drawn again.
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

        // Before anything is drawn, because the padding and the header size are
        // part of the same arithmetic that decides how much room the chart has.
        val bounds = boundsOf(context, manager, appWidgetId)
        views.setViewPadding(
            R.id.widget_container,
            bounds.paddingPx, bounds.paddingPx, bounds.paddingPx, bounds.paddingPx,
        )
        views.setTextViewTextSize(
            R.id.widget_name,
            TypedValue.COMPLEX_UNIT_SP,
            bounds.headerSp,
        )

        showLoading(views, manager, appWidgetId, server.name)

        CoroutineScope(Dispatchers.IO).launch {
            withTimeoutOrNull(COROUTINE_TIMEOUT) {
                try {
                    val (reading, history) = WidgetApi.load(context, server)
                    withContext(Dispatchers.Main) {
                        showData(context, views, manager, appWidgetId, config, reading, history, bounds)
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "Widget $appWidgetId update failed: ${e.message}")
                    val message = when (e) {
                        is WidgetApi.MissingTokenException,
                        is WidgetApi.RejectedTokenException,
                            -> R.string.widget_err_no_token
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

    /** The widget's size in grid cells, the chart area, and the chrome around it. */
    private data class Bounds(
        val columns: Int,
        val rows: Int,
        val widthPx: Int,
        val heightPx: Int,
        val density: Float,
        /** Applied to the container, so this and [heightPx] cannot disagree. */
        val paddingPx: Int,
        val headerSp: Float,
    )

    private fun boundsOf(context: Context, manager: AppWidgetManager, appWidgetId: Int): Bounds {
        val options = manager.getAppWidgetOptions(appWidgetId)
        // The launcher reports a *range*, and which end describes the view
        // depends on the orientation: in portrait the widget is at its minimum
        // width and its maximum height, in landscape the other way round.
        // Taking the minimum of both — which reads as the safe choice — gave a
        // box far shorter than the real one in portrait, and the image sat
        // letterboxed with a band of empty card above and below it.
        val portrait = context.resources.configuration.orientation ==
            Configuration.ORIENTATION_PORTRAIT
        val widthKey = if (portrait) {
            AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH
        } else {
            AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH
        }
        val heightKey = if (portrait) {
            AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT
        } else {
            AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT
        }
        val widthDp = options.getInt(widthKey, 0).takeIf { it > 0 }
            ?: options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 110)
                .takeIf { it > 0 } ?: 110
        val heightDp = options.getInt(heightKey, 0).takeIf { it > 0 }
            ?: options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 110)
                .takeIf { it > 0 } ?: 110
        val density = context.resources.displayMetrics.density

        // The launcher's own cell arithmetic, near enough: a cell is roughly
        // 70dp wide with 30dp of margin between.
        val columns = ((widthDp + 30) / 70).coerceAtLeast(1)
        val rows = ((heightDp + 30) / 70).coerceAtLeast(1)

        val charts = kind.drawsCharts
        val paddingDp = if (charts) CHART_PADDING_DP else READINGS_PADDING_DP
        val headerSp = if (charts) CHART_HEADER_SP else READINGS_HEADER_SP
        val marginDp = if (charts) CHART_MARGIN_DP else READINGS_CHART_MARGIN_DP

        val chartWidthDp = widthDp - paddingDp * 2
        val chartHeightDp =
            heightDp - paddingDp * 2 - headerSp * HEADER_LINE_RATIO - marginDp - FOOTER_DP

        return Bounds(
            columns = columns,
            rows = rows,
            widthPx = (chartWidthDp * density).roundToInt().coerceAtLeast(1),
            heightPx = (chartHeightDp * density).roundToInt().coerceAtLeast(1),
            density = density,
            paddingPx = (paddingDp * density).roundToInt(),
            headerSp = headerSp,
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

        // A broadcast back to this same provider, naming this one widget, which
        // `AppWidgetProvider.onReceive` turns into an `onUpdate` for it. The
        // receiver is not exported and does not need to be: a `PendingIntent`
        // is sent with the identity of the app that created it, and that is
        // this app.
        //
        // The `data` is what keeps the widgets apart. Two refresh intents differ
        // only in an extra, `filterEquals` does not look at extras, and the
        // flags say `FLAG_UPDATE_CURRENT` — so without it the second widget's
        // `PendingIntent` would rewrite the first one's target id and both
        // buttons would refresh the same widget.
        val refresh = Intent(context, javaClass).apply {
            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, intArrayOf(appWidgetId))
            data = android.net.Uri.parse("sbm://widget/refresh/$appWidgetId")
        }
        views.setOnClickPendingIntent(
            R.id.widget_refresh,
            PendingIntent.getBroadcast(context, appWidgetId, refresh, flag),
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
        // The footer says the reading's time, so during a fetch it has nothing
        // true to say. It is also the only acknowledgement the refresh button
        // gets — a `RemoteViews` cannot animate, and a tap that changes nothing
        // on screen reads as a tap that missed.
        views.setTextViewText(R.id.widget_time, "…")
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

        // No layout check and no "too small" state: the size and what it shows
        // are one decision, made when the widget was picked from the launcher,
        // and neither provider resizes.
        if (!kind.drawsCharts) {
            views.setViewVisibility(R.id.widget_chart, View.GONE)
            views.setViewVisibility(R.id.widget_content, View.VISIBLE)
            showReadings(views, reading)
        } else {
            val bitmap = WidgetChart.render(
                context = context,
                series = config.metric.following(WidgetKind.CHART_COUNT)
                    .map { seriesFor(context, it, reading, history) },
                widthPx = bounds.widthPx,
                heightPx = bounds.heightPx,
                density = bounds.density,
            )
            if (bitmap != null) {
                views.setImageViewBitmap(R.id.widget_chart, bitmap)
                views.setViewVisibility(R.id.widget_chart, View.VISIBLE)
                views.setViewVisibility(R.id.widget_content, View.GONE)
            } else {
                views.setViewVisibility(R.id.widget_chart, View.GONE)
                views.setViewVisibility(R.id.widget_content, View.VISIBLE)
                showReadings(views, reading)
            }
        }
        manager.updateAppWidget(appWidgetId, views)
    }

    /**
     * All four readings, which is the whole of what the small widget is for.
     *
     * It used to show two of them, on the theory that four rows do not fit in
     * something the size of an app icon. They do — and once the medium widget
     * became charts-only there was no size left where the other two would ever
     * appear, since this is only ever called for [WidgetKind.SMALL] at 2x2.
     *
     * Percentages rather than the "4.2g / 8.0g" forms: fifteen monospace
     * characters do not fit a row about 94dp wide, and a truncated pair of
     * numbers says less than one whole one. Network has no percentage, so it
     * gets the shortened byte counts.
     */
    private fun showReadings(views: RemoteViews, reading: WidgetApi.Reading) {
        views.setTextViewText(R.id.widget_cpu, percentText(reading.cpu))
        views.setTextViewText(R.id.widget_mem, percentText(reading.mem))
        views.setTextViewText(R.id.widget_disk, percentText(reading.disk))
        views.setTextViewText(R.id.widget_net, shortNet(reading.netText))
        for (row in listOf(
            R.id.widget_cpu_label,
            R.id.widget_mem_label,
            R.id.widget_disk_label,
            R.id.widget_net_label,
        )) {
            views.setViewVisibility(row, View.VISIBLE)
        }
    }

    /**
     * "93.2m / 75.3m" -> "93m/75m".
     *
     * Six characters back, which is the difference between fitting a narrow
     * row and not. Used by the readings widget and as the chart panel's last
     * resort when the full form will not fit beside its label.
     */
    private fun shortNet(netText: String): String =
        netText.replace(" / ", "/").replace(Regex("\\.[0-9]"), "")

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
        // It dates a reading, and there is none. Left alone it would still be
        // showing the ellipsis `showLoading` put there, which claims a fetch is
        // in flight when one has just failed. The refresh button stays: this is
        // the state it is most use in.
        views.setViewVisibility(R.id.widget_time, View.GONE)
        manager.updateAppWidget(appWidgetId, views)
    }

    // MARK: - Reading a metric

    private fun percentText(value: Double?): String =
        value?.let { String.format(java.util.Locale.US, "%.0f%%", it) } ?: "--"

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
            valueShort = percentText(reading.cpu),
            color = Color.parseColor("#34C759"),
        )
        WidgetMetric.MEMORY -> WidgetChart.Series(
            label = context.getString(R.string.widget_metric_memory),
            values = history.map { it.memory },
            secondary = emptyList(),
            isPercent = true,
            valueText = percentText(reading.mem),
            valueShort = percentText(reading.mem),
            color = Color.parseColor("#0A84FF"),
        )
        WidgetMetric.DISK -> WidgetChart.Series(
            label = context.getString(R.string.widget_metric_disk),
            values = history.map { it.disk },
            secondary = emptyList(),
            isPercent = true,
            valueText = percentText(reading.disk),
            valueShort = percentText(reading.disk),
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
            valueShort = shortNet(reading.netText),
            color = Color.parseColor("#BF5AF2"),
        )
    }
}

/** 2x2, readings as text. */
class StatusWidgetSmall : HomeWidget(WidgetKind.SMALL)

/** 4x2, charts. */
class StatusWidgetMedium : HomeWidget(WidgetKind.MEDIUM)
