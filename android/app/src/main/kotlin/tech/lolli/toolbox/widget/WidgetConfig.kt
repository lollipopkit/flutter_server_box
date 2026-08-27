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
    val metric: WidgetMetric,
) {
    companion object {
        private const val PREFS = "sbm_widget_config"

        fun load(context: Context, appWidgetId: Int): WidgetConfig {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            return WidgetConfig(
                serverId = prefs.getString(key(appWidgetId, "server"), "") ?: "",
                metric = WidgetMetric.from(prefs.getString(key(appWidgetId, "metric"), null)),
            )
        }

        fun save(context: Context, appWidgetId: Int, config: WidgetConfig) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .putString(key(appWidgetId, "server"), config.serverId)
                .putString(key(appWidgetId, "metric"), config.metric.name)
                .apply()
        }

        fun forget(context: Context, appWidgetId: Int) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .remove(key(appWidgetId, "server"))
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

/**
 * Which of the two widgets this is.
 *
 * Two fixed providers rather than one that resizes. The size and what it can
 * show are the same decision — a 2x2 holds readings and a 4x2 holds charts —
 * so binding them removes the case where a layout was chosen and the size
 * quietly overruled it. It is also what puts both in the launcher's picker as
 * separate entries, which is where someone chooses a widget.
 */
enum class WidgetKind {
    /** 2x2, readings as text. Nothing to configure beyond the server. */
    SMALL,

    /** 4x2, one chart per metric. */
    MEDIUM;

    val drawsCharts: Boolean get() = this == MEDIUM

    companion object {
        /**
         * Every metric, always.
         *
         * Not a choice. A medium widget has room for the four panels and no
         * reason to draw fewer — asking how many charts someone wants is a
         * question with one sensible answer, and a setting whose only effect
         * is to show less.
         */
        const val CHART_COUNT = 4
    }
}
