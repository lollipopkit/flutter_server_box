package tech.lolli.toolbox.widget

import android.content.Context

/**
 * What one placed widget was configured to show.
 *
 * Keyed by `appWidgetId`, which is the system's identity for a widget instance
 * and survives a reboot but not a removal — so a widget dragged off the home
 * screen and back is a new one with nothing to inherit, which is correct.
 */
data class WidgetConfig(
    /** [WidgetStore.WidgetServer.id], or empty when nothing is picked yet. */
    val serverId: String,
    val layout: WidgetLayout,
    val metric: WidgetMetric,
) {
    companion object {
        private const val PREFS = "sbm_widget_config"

        fun load(context: Context, appWidgetId: Int): WidgetConfig {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            return WidgetConfig(
                serverId = prefs.getString(key(appWidgetId, "server"), "") ?: "",
                layout = WidgetLayout.from(prefs.getString(key(appWidgetId, "layout"), null)),
                metric = WidgetMetric.from(prefs.getString(key(appWidgetId, "metric"), null)),
            )
        }

        fun save(context: Context, appWidgetId: Int, config: WidgetConfig) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .putString(key(appWidgetId, "server"), config.serverId)
                .putString(key(appWidgetId, "layout"), config.layout.name)
                .putString(key(appWidgetId, "metric"), config.metric.name)
                .apply()
        }

        fun forget(context: Context, appWidgetId: Int) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .remove(key(appWidgetId, "server"))
                .remove(key(appWidgetId, "layout"))
                .remove(key(appWidgetId, "metric"))
                .apply()
        }

        private fun key(id: Int, field: String) = "widget_${id}_$field"
    }
}

/** One reading a widget can lead with. */
enum class WidgetMetric {
    CPU,
    MEMORY,
    DISK,
    NETWORK;

    companion object {
        /**
         * Stored and read **by name**, never by ordinal: an ordinal silently
         * changes meaning when a case is inserted, and a widget's
         * configuration outlives the build that wrote it.
         */
        fun from(name: String?): WidgetMetric =
            entries.firstOrNull { it.name == name } ?: CPU

        /** The order charts fill a widget in, starting from whichever was chosen. */
        val rotation = listOf(CPU, MEMORY, DISK, NETWORK)
    }

    /** [count] metrics beginning at this one, wrapping around. */
    fun following(count: Int): List<WidgetMetric> {
        val start = rotation.indexOf(this).coerceAtLeast(0)
        return (0 until minOf(count, rotation.size)).map {
            rotation[(start + it) % rotation.size]
        }
    }
}

/** How much of the widget is given to charts rather than to numbers. */
enum class WidgetLayout {
    TEXT,
    ONE_CHART,
    TWO_CHARTS,
    FOUR_CHARTS;

    companion object {
        /** What "medium" means in cells — a standard 4x2 widget. */
        const val MEDIUM_COLUMNS = 4
        const val MEDIUM_ROWS = 2

        /** By name, for the reason in [WidgetMetric.from]. */
        fun from(name: String?): WidgetLayout =
            entries.firstOrNull { it.name == name } ?: TEXT
    }

    /** How many charts this draws. */
    val chartCount: Int
        get() = when (this) {
            TEXT -> 0
            ONE_CHART -> 1
            TWO_CHARTS -> 2
            FOUR_CHARTS -> 4
        }

    /**
     * Whether a widget [columns] by [rows] cells has room for it.
     *
     * Two panels side by side need the width of a medium widget — four cells,
     * the same shape iOS calls `.systemMedium`. Below that a panel is a smudge.
     *
     * Checked rather than narrowed. It used to quietly turn four charts into
     * one on a small widget, which reads as the setting having no effect and
     * leaves nowhere to find out otherwise. The widget says so instead: the
     * choice is kept, and dragging the widget wider brings it back.
     */
    fun fits(columns: Int, rows: Int): Boolean =
        chartCount <= 1 || (columns >= MEDIUM_COLUMNS && rows >= MEDIUM_ROWS)
}
