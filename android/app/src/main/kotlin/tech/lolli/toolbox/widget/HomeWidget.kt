package tech.lolli.toolbox.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.util.SizeF
import android.view.View
import android.widget.RemoteViews
import androidx.core.os.BundleCompat
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import org.json.JSONException
import tech.lolli.toolbox.MainActivity
import tech.lolli.toolbox.R
import java.io.IOException
import java.net.SocketTimeoutException
import java.util.Locale
import java.util.concurrent.ConcurrentHashMap
import kotlin.math.roundToInt

/** One fetch, kept to draw again at a new size or under a refresh. */
private class Data(
    val reading: WidgetApi.Reading,
    val history: List<WidgetApi.HistoryPoint>,
    val config: WidgetConfig,
    val time: String,
)

/**
 * The home-screen widget.
 *
 * Reads the agent's `/api/v1` endpoints with the scoped, read-only token the
 * app published — see `WidgetStore`. An `AppWidgetProvider` is a
 * `BroadcastReceiver` in the app's own process, so everything it needs is
 * readable without a channel hop.
 *
 * One design at every size: what it shows follows the space the launcher gives
 * it and the text it is about to show ([WidgetForms]), and on Android 12+ each
 * size the launcher may show it at (portrait and landscape) gets its own
 * rendering, drawn for that size.
 */
abstract class HomeWidget : AppWidgetProvider() {
    companion object {
        /** Every provider, for the callers that mean "every widget". */
        val providers = listOf(
            StatusWidget::class.java,
            StatusWidgetSmall::class.java,
            StatusWidgetMedium::class.java,
        )

        /** Asks every placed widget to refresh. */
        fun broadcastUpdate(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            for (provider in providers) {
                context.sendBroadcast(
                    Intent(context, provider).apply {
                        action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                        putExtra(
                            AppWidgetManager.EXTRA_APPWIDGET_IDS,
                            manager.getAppWidgetIds(ComponentName(context, provider)),
                        )
                    }
                )
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
         * The last fetch per widget, while the process lives: a resize is
         * drawn again from it without a round trip — which on a slow or
         * unreachable server would have replaced readings with an error — and
         * a refresh shows it, marked as refreshing, until the new one lands.
         */
        private val lastData = ConcurrentHashMap<Int, Data>()

        /** Trends per rendering: `widget_large` has two. */
        private const val MAX_CHARTS = 2

        /** A meter turns to the warning colour from here, in percent. */
        private const val WARN_PERCENT = 90.0

        /** The refresh button while one is in flight: dimmed. */
        private const val REFRESHING_ALPHA = 90

        private const val PREVIEW_PREFS = "widget_preview"
        private const val KEY_PREVIEW_STAMP = "stamp"

        /** The size the picker's preview is drawn at: a 4x2 on a phone. */
        private val PREVIEW_SIZE = SizeF(340f, 180f)

        /**
         * The launcher picker's preview (Android 15+), drawn by the same code
         * as a placed widget from made-up readings. Once per install and
         * language: the system limits how often previews may be set, and a
         * call it refuses is retried on a later launch.
         */
        fun publishPreviews(context: Context) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.VANILLA_ICE_CREAM) return
            val prefs = context.getSharedPreferences(PREVIEW_PREFS, Context.MODE_PRIVATE)
            // The install, not the version: the system drops generated previews
            // on every package update, a reinstall of the same version included.
            val installed = context.packageManager.getPackageInfo(context.packageName, 0).lastUpdateTime
            val stamp = "$installed/${context.resources.configuration.locales.toLanguageTags()}"
            val key = "$KEY_PREVIEW_STAMP/${StatusWidget::class.java.simpleName}"
            if (prefs.getString(key, null) == stamp) return
            val ok = try {
                AppWidgetManager.getInstance(context).setWidgetPreview(
                    ComponentName(context, StatusWidget::class.java),
                    android.appwidget.AppWidgetProviderInfo.WIDGET_CATEGORY_HOME_SCREEN,
                    StatusWidget().preview(context),
                )
            } catch (e: Exception) {
                Log.w(TAG, "setWidgetPreview: ${e.message}")
                false
            }
            if (ok) prefs.edit().putString(key, stamp).apply()
            else Log.i(TAG, "setWidgetPreview refused; retried next launch")
        }

        private val SAMPLE_READING = WidgetApi.Reading(
            name = "web-01",
            cpu = 23.0,
            mem = 61.0,
            disk = 48.0,
            memText = "4.9g / 8.0g",
            diskText = "48g / 100g",
        )

        private val SAMPLE_HISTORY = (0 until 40).map { i ->
            val t = i / 39.0
            WidgetApi.HistoryPoint(
                cpu = 16 + 9 * kotlin.math.sin(t * 9) + 5 * kotlin.math.sin(t * 23) + 4 * t,
                memory = 55 + 6 * t,
                disk = 47 + t,
                netRx = 600_000 + 500_000 * kotlin.math.sin(t * 5 + 1).coerceAtLeast(0.0),
                netTx = 200_000 + 150_000 * kotlin.math.sin(t * 4),
            )
        }
    }

    private val WidgetForm.layout: Int
        get() = when (this) {
            WidgetForm.TINY -> R.layout.widget_tiny
            WidgetForm.SMALL -> R.layout.widget_small
            WidgetForm.MEDIUM -> R.layout.widget_medium
            WidgetForm.LARGE -> R.layout.widget_large
        }

    /** This widget with [SAMPLE_READING], at the size the picker shows it. */
    fun preview(context: Context): RemoteViews {
        val data = Data(SAMPLE_READING, SAMPLE_HISTORY, WidgetConfig("", WidgetMetric.CPU), "12:00")
        return build(context, PREVIEW_SIZE, data, tap = null, refreshing = false, WidgetChart.BUDGET_PIXELS / MAX_CHARTS)
    }

    override fun onUpdate(context: Context, manager: AppWidgetManager, appWidgetIds: IntArray) {
        for (id in appWidgetIds) update(context, manager, id)
    }

    /**
     * Resized, or a launcher with a different grid: drawn again for the new
     * size, from the last fetch when there is one.
     */
    override fun onAppWidgetOptionsChanged(
        context: Context,
        manager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        val data = lastData[appWidgetId]
        if (data == null) {
            update(context, manager, appWidgetId)
            return
        }
        CoroutineScope(Dispatchers.Default).launch {
            val views = render(context, manager, appWidgetId, data, refreshing = false)
            withContext(Dispatchers.Main) { manager.updateAppWidget(appWidgetId, views) }
        }
    }

    /** A widget dragged off the home screen must not leave its choices behind. */
    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        for (id in appWidgetIds) {
            WidgetConfig.forget(context, id)
            lastData.remove(id)
        }
    }

    private fun update(context: Context, manager: AppWidgetManager, appWidgetId: Int) {
        // Two updates for one widget would race each other onto the screen,
        // and the loser's `updateAppWidget` is the one that sticks.
        if (activeUpdates.putIfAbsent(appWidgetId, true) == true) {
            Log.d(TAG, "Widget $appWidgetId is already updating, skipping")
            return
        }

        val config = WidgetConfig.load(context, appWidgetId)
        val server = config.serverId.takeIf { it.isNotEmpty() }
            ?.let { WidgetStore.server(context, it) }
        if (server == null) {
            // Either nothing has been picked, or the server was deleted in the
            // app after this widget was pointed at it. Both are fixed in the
            // same place, which is where tapping the widget goes.
            lastData.remove(appWidgetId)
            showMessage(context, manager, appWidgetId, null, context.getString(R.string.widget_err_not_configured))
            activeUpdates.remove(appWidgetId)
            return
        }

        CoroutineScope(Dispatchers.IO).launch {
            // The guard is released here and nowhere else: anything thrown past
            // the handlers below — a cancellation, an Error — would otherwise
            // leave it held for the life of the process, and every later
            // update of this widget would be skipped.
            try {
                // The only acknowledgement a refresh gets — a `RemoteViews`
                // cannot animate, and a tap that changes nothing reads as one
                // that missed: the readings stay, marked as refreshing. A full
                // update, since a partial one does not reach the per-size
                // renderings of Android 12+.
                lastData[appWidgetId]?.takeIf { it.config == config }?.let { previous ->
                    val views = render(context, manager, appWidgetId, previous, refreshing = true)
                    withContext(Dispatchers.Main) { manager.updateAppWidget(appWidgetId, views) }
                }
                withTimeoutOrNull(COROUTINE_TIMEOUT) {
                    try {
                        val (reading, history) = WidgetApi.load(context, server)
                        val time = android.text.format.DateFormat.getTimeFormat(context)
                            .format(java.util.Date())
                        val data = Data(reading, history, config, time)
                        val views = render(context, manager, appWidgetId, data, refreshing = false)
                        lastData[appWidgetId] = data
                        withContext(Dispatchers.Main) { manager.updateAppWidget(appWidgetId, views) }
                    } catch (e: CancellationException) {
                        // Belongs to `withTimeoutOrNull`, which is watching for it.
                        throw e
                    } catch (e: Exception) {
                        Log.w(TAG, "Widget $appWidgetId update failed: ${e.message}")
                        val message = when (e) {
                            is WidgetApi.MissingTokenException,
                            is WidgetApi.RejectedTokenException,
                                -> R.string.widget_err_no_token
                            is WidgetApi.InsecureException -> R.string.widget_err_insecure
                            is SocketTimeoutException -> R.string.widget_err_timeout
                            is JSONException, is IOException -> R.string.widget_err_network
                            else -> R.string.widget_err_network
                        }
                        withContext(Dispatchers.Main) {
                            showMessage(context, manager, appWidgetId, server, context.getString(message))
                        }
                    }
                } ?: run {
                    Log.w(TAG, "Widget $appWidgetId update timed out")
                    withContext(Dispatchers.Main) {
                        showMessage(context, manager, appWidgetId, server, context.getString(R.string.widget_err_timeout))
                    }
                }
            } finally {
                activeUpdates.remove(appWidgetId)
            }
        }
    }

    // MARK: - Sizes

    /**
     * Every size the widget may be shown at, in dp.
     *
     * Android 12+ reports them (`OPTION_APPWIDGET_SIZES`: portrait and
     * landscape, usually). Below that, one size read off the reported range,
     * whose useful end depends on the orientation: portrait shows the minimum
     * width and the maximum height, landscape the other way round.
     */
    private fun sizesOf(context: Context, manager: AppWidgetManager, appWidgetId: Int): List<SizeF> {
        val options = manager.getAppWidgetOptions(appWidgetId)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val sizes = BundleCompat.getParcelableArrayList(
                options, AppWidgetManager.OPTION_APPWIDGET_SIZES, SizeF::class.java,
            )
            if (!sizes.isNullOrEmpty()) return sizes.distinct()
        }
        val portrait = context.resources.configuration.orientation == Configuration.ORIENTATION_PORTRAIT
        fun read(key: String, fallback: String) =
            options.getInt(key, 0).takeIf { it > 0 } ?: options.getInt(fallback, 0).takeIf { it > 0 }
        val w = read(
            if (portrait) AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH else AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH,
            AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH,
        ) ?: 250
        val h = read(
            if (portrait) AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT else AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT,
            AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT,
        ) ?: 110
        return listOf(SizeF(w.toFloat(), h.toFloat()))
    }

    // MARK: - Rendering

    private fun render(
        context: Context,
        manager: AppWidgetManager,
        appWidgetId: Int,
        data: Data,
        refreshing: Boolean,
    ): RemoteViews {
        val sizes = sizesOf(context, manager, appWidgetId)
        val tap = openIntent(context, appWidgetId, data.config.serverId)
        val refresh = refreshIntent(context, appWidgetId)
        // One transaction carries every rendering, so the bitmap budget is
        // shared between all of their trends.
        val perChart = WidgetChart.BUDGET_PIXELS / (sizes.size * MAX_CHARTS)
        fun one(size: SizeF) = build(context, size, data, tap, refreshing, perChart).also {
            it.setOnClickPendingIntent(R.id.widget_refresh, refresh)
        }
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && sizes.size > 1) {
            RemoteViews(sizes.associateWith { one(it) })
        } else {
            one(sizes.first())
        }
    }

    private fun build(
        context: Context,
        size: SizeF,
        data: Data,
        tap: PendingIntent?,
        refreshing: Boolean,
        chartPixels: Int,
    ): RemoteViews {
        val fontScale = context.resources.configuration.fontScale
        val hero = data.config.metric
        val others = hero.following(WidgetMetric.entries.size).drop(1)
        // Meters for the two that have one (`widget_small`), so a network lead
        // does not leave a row without a bar.
        val metered = others.filter { it.isPercent }.take(2)
        val content = WidgetContent(
            hero = heroValue(hero, data),
            label = context.getString(hero.labelRes),
            caption = heroCaption(context, hero, data),
            meterLabels = others.map { context.getString(it.labelRes) },
            meterValues = others.map { valueText(it, data, long = false) },
            side = others.take(2).map { inline(context, it, data) },
        )
        val form = WidgetForms.formFor(size.width, size.height, fontScale, content)
        val views = RemoteViews(context.packageName, form.layout)
        val density = context.resources.displayMetrics.density
        tap?.let { views.setOnClickPendingIntent(R.id.widget_root, it) }

        views.setTextViewText(R.id.widget_name, data.reading.name)
        views.setTextViewText(R.id.widget_time, if (refreshing) "…" else data.time)
        if (refreshing) views.setInt(R.id.widget_refresh, "setImageAlpha", REFRESHING_ALPHA)
        views.setTextViewText(R.id.hero_value, content.hero)
        views.setTextViewText(R.id.hero_caption, content.caption)

        when (form) {
            WidgetForm.TINY -> {
                val fit = WidgetForms.tiny(size.width, fontScale, content)
                when (fit.caption) {
                    WidgetForms.TinyCaption.NONE -> views.setViewVisibility(R.id.hero_caption, View.GONE)
                    WidgetForms.TinyCaption.LABEL -> views.setTextViewText(R.id.hero_caption, content.label)
                    WidgetForms.TinyCaption.FULL -> Unit
                }
                views.setTextViewText(R.id.s1_value, content.side[0])
                views.setTextViewText(R.id.s2_value, content.side[1])
                views.setViewVisibility(R.id.tiny_side, if (fit.side) View.VISIBLE else View.GONE)
            }
            WidgetForm.SMALL -> {
                bindStat(context, views, 1, metered[0], data)
                bindStat(context, views, 2, metered[1], data)
            }
            WidgetForm.MEDIUM, WidgetForm.LARGE -> {
                val stacked = WidgetForms.metersStacked(size.width, fontScale, content)
                others.forEachIndexed { i, m -> bindStat(context, views, i + 1, m, data, stacked) }
                val (w, h) = WidgetForms.heroChartBox(form, size.width, size.height, fontScale, content)
                setChart(views, R.id.hero_chart, hero, data, w, h, density, chartPixels)
                if (form == WidgetForm.LARGE) {
                    // The most telling of the rest: network moves, disk does not.
                    val second = if (hero == WidgetMetric.NETWORK) WidgetMetric.CPU else WidgetMetric.NETWORK
                    views.setTextViewText(R.id.second_label, context.getString(second.labelRes))
                    views.setTextViewText(R.id.second_value, valueText(second, data, long = true))
                    val (sw, sh) = WidgetForms.secondChartBox(size.width, size.height, fontScale, content)
                    setChart(views, R.id.second_chart, second, data, sw, sh, density, chartPixels)
                }
            }
        }
        return views
    }

    /** A meter; a two-part value on two lines when [stacked] ([WidgetForms.metersStacked]). */
    private fun bindStat(
        context: Context,
        views: RemoteViews,
        index: Int,
        metric: WidgetMetric,
        data: Data,
        stacked: Boolean = false,
    ) {
        val (label, value, bar, warn) = when (index) {
            1 -> StatIds(R.id.s1_label, R.id.s1_value, R.id.s1_bar, R.id.s1_bar_warn)
            2 -> StatIds(R.id.s2_label, R.id.s2_value, R.id.s2_bar, R.id.s2_bar_warn)
            else -> StatIds(R.id.s3_label, R.id.s3_value, R.id.s3_bar, R.id.s3_bar_warn)
        }
        views.setTextViewText(label, context.getString(metric.labelRes))
        val text = valueText(metric, data, long = false)
        views.setTextViewText(value, if (stacked) text.replace(' ', '\n') else text)
        if (!metric.isPercent) {
            views.setViewVisibility(bar, View.GONE)
            views.setViewVisibility(warn, View.GONE)
            return
        }
        val percent = percentOf(metric, data) ?: 0.0
        val high = percent >= WARN_PERCENT
        views.setViewVisibility(bar, if (high) View.GONE else View.VISIBLE)
        views.setViewVisibility(warn, if (high) View.VISIBLE else View.GONE)
        views.setProgressBar(if (high) warn else bar, 100, percent.roundToInt().coerceIn(0, 100), false)
    }

    private data class StatIds(val label: Int, val value: Int, val bar: Int, val warn: Int)

    /**
     * [metric]'s trend into [id], drawn for a [widthDp] x [heightDp] box: an
     * estimate — a `RemoteViews` cannot be measured — that the `ImageView`
     * scales to fit, so being out only bends the line a little.
     */
    private fun setChart(
        views: RemoteViews,
        id: Int,
        metric: WidgetMetric,
        data: Data,
        widthDp: Float,
        heightDp: Float,
        density: Float,
        maxPixels: Int,
    ) {
        val history = data.history
        val bitmap = WidgetChart.render(
            values = history.map { metric.of(it) },
            secondary = if (metric == WidgetMetric.NETWORK) history.map { it.netTx } else emptyList(),
            isPercent = metric.isPercent,
            widthPx = (widthDp * density).roundToInt(),
            heightPx = (heightDp * density).roundToInt(),
            density = density,
            maxPixels = maxPixels,
        )
        if (bitmap == null) {
            views.setViewVisibility(id, View.INVISIBLE)
        } else {
            views.setImageViewBitmap(id, bitmap)
            views.setViewVisibility(id, View.VISIBLE)
        }
    }

    // MARK: - States

    private fun showMessage(
        context: Context,
        manager: AppWidgetManager,
        appWidgetId: Int,
        server: WidgetStore.WidgetServer?,
        message: String,
    ) {
        val views = RemoteViews(context.packageName, R.layout.widget_message)
        views.setTextViewText(R.id.widget_name, server?.name ?: context.getString(R.string.app_name))
        views.setTextViewText(R.id.widget_message, message)
        // Unconfigured, a tap is how it gets configured; otherwise it opens
        // the server, where whatever went wrong can be looked at.
        views.setOnClickPendingIntent(
            R.id.widget_root,
            if (server == null) configureIntent(context, appWidgetId) else openIntent(context, appWidgetId, server.id),
        )
        if (server == null) {
            views.setViewVisibility(R.id.widget_refresh, View.GONE)
        } else {
            views.setOnClickPendingIntent(R.id.widget_refresh, refreshIntent(context, appWidgetId))
        }
        manager.updateAppWidget(appWidgetId, views)
    }

    // MARK: - Intents

    private val immutable = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE

    /**
     * The server in the app (`serverbox://server/<id>`), on Android 12+. Below
     * that a launcher has no "reconfigure" entry on the widget, so the tap is
     * the only way back to its settings and keeps opening them.
     */
    private fun openIntent(context: Context, appWidgetId: Int, serverId: String): PendingIntent {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return configureIntent(context, appWidgetId)
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse("serverbox://server/${Uri.encode(serverId)}"), context, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        return PendingIntent.getActivity(context, appWidgetId, intent, immutable)
    }

    private fun configureIntent(context: Context, appWidgetId: Int): PendingIntent {
        val intent = Intent(context, WidgetConfigureActivity::class.java).apply {
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            // Without this the reused activity keeps the first widget's extras
            // and every widget reconfigures the same one.
            data = Uri.parse("sbm://widget/$appWidgetId")
        }
        return PendingIntent.getActivity(context, appWidgetId, intent, immutable)
    }

    /**
     * A broadcast back to this provider naming this one widget, which
     * `AppWidgetProvider.onReceive` turns into an `onUpdate` for it. The `data`
     * keeps the widgets apart: `filterEquals` ignores extras, so without it a
     * second widget's intent would overwrite the first one's target.
     */
    private fun refreshIntent(context: Context, appWidgetId: Int): PendingIntent {
        val refresh = Intent(context, javaClass).apply {
            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, intArrayOf(appWidgetId))
            data = Uri.parse("sbm://widget/refresh/$appWidgetId")
        }
        return PendingIntent.getBroadcast(context, appWidgetId, refresh, immutable)
    }

    // MARK: - Reading a metric

    private fun percentOf(metric: WidgetMetric, data: Data): Double? = when (metric) {
        WidgetMetric.CPU -> data.reading.cpu
        WidgetMetric.MEMORY -> data.reading.mem
        WidgetMetric.DISK -> data.reading.disk
        WidgetMetric.NETWORK -> null
    }

    private fun percentText(value: Double?): String =
        value?.let { String.format(Locale.US, "%.0f%%", it) } ?: "--"

    /**
     * A byte count in as few glyphs as reads well: "340k", "1.2m". One
     * decimal only below ten, where it is a tenth of the number rather than
     * a hundredth.
     */
    private fun compact(bytes: Double): String {
        val units = listOf("b", "k", "m", "g", "t")
        var value = bytes.coerceAtLeast(0.0)
        var unit = 0
        while (value >= 1000 && unit < units.size - 1) {
            value /= 1024
            unit++
        }
        val number = if (unit == 0 || value >= 10) String.format(Locale.US, "%.0f", value)
        else String.format(Locale.US, "%.1f", value)
        return number + units[unit]
    }

    /**
     * Network as a rate, from the newest history point: the reading's own
     * byte counts are totals since boot, which say nothing about now.
     */
    private fun rate(bytesPerSecond: Double?): String =
        bytesPerSecond?.let { "${compact(it)}/s" } ?: "--"

    private fun valueText(metric: WidgetMetric, data: Data, long: Boolean): String {
        if (metric.isPercent) return percentText(percentOf(metric, data))
        val last = data.history.lastOrNull()
        if (long) return "↓ ${rate(last?.netRx)}  ↑ ${rate(last?.netTx)}"
        val down = last?.netRx?.let { compact(it) } ?: "--"
        val up = last?.netTx?.let { compact(it) } ?: "--"
        return "↓$down ↑$up"
    }

    private fun heroValue(metric: WidgetMetric, data: Data): String =
        if (metric.isPercent) percentText(percentOf(metric, data)) else rate(data.history.lastOrNull()?.netRx)

    /** What the big number is, and the detail that fits under it. */
    private fun heroCaption(context: Context, metric: WidgetMetric, data: Data): String {
        val name = context.getString(metric.labelRes)
        val detail = when (metric) {
            WidgetMetric.MEMORY -> data.reading.memText
            WidgetMetric.DISK -> data.reading.diskText
            WidgetMetric.NETWORK -> "↑ ${rate(data.history.lastOrNull()?.netTx)}"
            WidgetMetric.CPU -> null
        }
        return if (detail.isNullOrEmpty()) name else "$name · $detail"
    }

    /** "Memory 61%", for the one-row widget. */
    private fun inline(context: Context, metric: WidgetMetric, data: Data): String =
        "${context.getString(metric.labelRes)} ${valueText(metric, data, long = false)}"
}

private fun WidgetMetric.of(point: WidgetApi.HistoryPoint): Double = when (this) {
    WidgetMetric.CPU -> point.cpu
    WidgetMetric.MEMORY -> point.memory
    WidgetMetric.DISK -> point.disk
    WidgetMetric.NETWORK -> point.netRx
}

/** The widget, at any size. */
class StatusWidget : HomeWidget()

/** TODO: remove with `widget_small.xml`; a 2x2 placed before `StatusWidget`. */
class StatusWidgetSmall : HomeWidget()

/** TODO: remove with `widget_medium.xml`; a 4x2 placed before `StatusWidget`. */
class StatusWidgetMedium : HomeWidget()
