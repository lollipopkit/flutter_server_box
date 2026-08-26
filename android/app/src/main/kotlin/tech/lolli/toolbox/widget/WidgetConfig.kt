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
        /** By name, for the reason in [WidgetMetric.from]. */
        fun from(name: String?): WidgetLayout =
            entries.firstOrNull { it.name == name } ?: TEXT
    }

    /**
     * What this layout becomes in a widget [columns] by [rows] cells.
     *
     * Narrowed at draw time rather than restricted at configuration time,
     * because on Android the size is not chosen once: the widget is resized in
     * place, whenever, and a choice that had been taken away would have no way
     * to come back. Asking for four charts and shrinking to 2x2 gives one
     * chart; growing again gives four back.
     */
    fun resolved(columns: Int, rows: Int): WidgetLayout {
        if (this == TEXT) return TEXT
        // Two panels side by side need the width; four need both. Below that a
        // panel is a smudge, and one readable chart beats four unreadable ones.
        return when {
            columns >= 4 && rows >= 3 -> this
            columns >= 4 -> if (this == FOUR_CHARTS) TWO_CHARTS else this
            else -> ONE_CHART
        }
    }
}
