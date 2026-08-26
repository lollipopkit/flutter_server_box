package tech.lolli.toolbox.widget

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import android.view.View
import android.widget.ArrayAdapter
import android.widget.Button
import android.widget.LinearLayout
import android.widget.RadioButton
import android.widget.RadioGroup
import android.widget.Spinner
import android.widget.TextView
import tech.lolli.toolbox.R

/**
 * What a widget shows: which server, and which metric leads.
 *
 * Serves both providers. Which one is being configured comes from the id, not
 * from an extra: the launcher hands over an `appWidgetId` and the system knows
 * what it belongs to. What each one *draws* is not configurable — that is the
 * point of there being two of them.
 *
 * The servers are the ones the app published (`WidgetStore`), not an address
 * typed in here. There is no free-text field any more and that is deliberate:
 * the widget reads the agent's authenticated API, so an address on its own is
 * useless — reaching one needs a login, and a login typed into a widget
 * configuration dialog would be a second place credentials live, worse in
 * every way than adding the server in the app.
 */
class WidgetConfigureActivity : Activity() {
    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID
    private var servers: List<WidgetStore.WidgetServer> = emptyList()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.widget_configure)

        // In case the user backs out before finishing: the system removes a
        // widget whose configuration activity did not answer RESULT_OK.
        setResult(RESULT_CANCELED)

        appWidgetId = intent.extras?.getInt(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID
        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }

        servers = WidgetStore.servers(applicationContext)
        val form = findViewById<LinearLayout>(R.id.config_form)
        val emptyHint = findViewById<TextView>(R.id.empty_hint)
        if (servers.isEmpty()) {
            form.visibility = View.GONE
            emptyHint.visibility = View.VISIBLE
            return
        }

        val existing = WidgetConfig.load(applicationContext, appWidgetId)
        val serverGroup = buildServerList(existing)
        val metricSpinner = buildMetricSpinner(existing)

        findViewById<Button>(R.id.save_button).setOnClickListener {
            val index = serverGroup.checkedRadioButtonId
            if (index !in servers.indices) return@setOnClickListener

            WidgetConfig.save(
                applicationContext,
                appWidgetId,
                WidgetConfig(
                    serverId = servers[index].id,
                    metric = WidgetMetric.entries[metricSpinner.selectedItemPosition],
                ),
            )

            // Targeted at this widget, and at its own provider: reconfiguring
            // one must not make every other widget on the screen refetch.
            val provider = AppWidgetManager.getInstance(applicationContext)
                .getAppWidgetInfo(appWidgetId)?.provider
            if (provider != null) {
                sendBroadcast(
                    Intent(AppWidgetManager.ACTION_APPWIDGET_UPDATE).apply {
                        component = provider
                        putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, intArrayOf(appWidgetId))
                    }
                )
            }

            setResult(
                RESULT_OK,
                Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId),
            )
            finish()
        }
    }

    /**
     * The radio button ids are indices into [servers].
     *
     * A server id is a string and `RadioGroup` keys by int, so the mapping has
     * to exist somewhere; an index into the list this screen was built from is
     * the one that cannot drift while the screen is open.
     */
    private fun buildServerList(existing: WidgetConfig): RadioGroup {
        val group = findViewById<RadioGroup>(R.id.server_group)
        servers.forEachIndexed { index, server ->
            group.addView(
                RadioButton(this).apply {
                    id = index
                    text = if (server.name == WidgetApi.displayHost(server.addr)) {
                        server.name
                    } else {
                        // Two servers can share a name; the host is what tells
                        // them apart.
                        "${server.name}  ·  ${WidgetApi.displayHost(server.addr)}"
                    }
                    isChecked = server.id == existing.serverId
                }
            )
        }
        // Nothing picked yet, or the previous choice was deleted in the app.
        if (group.checkedRadioButtonId !in servers.indices) group.check(0)
        return group
    }

    // Labels derived from the enum rather than listed beside it, so
    // reordering a case cannot leave the spinner offering the wrong words for
    // the right positions — which is silent, and stored by name, so it would
    // only show up as widgets drawing something nobody asked for.
    private fun buildMetricSpinner(existing: WidgetConfig): Spinner {
        val labels = WidgetMetric.entries.map {
            getString(
                when (it) {
                    WidgetMetric.CPU -> R.string.widget_metric_cpu
                    WidgetMetric.MEMORY -> R.string.widget_metric_memory
                    WidgetMetric.DISK -> R.string.widget_metric_disk
                    WidgetMetric.NETWORK -> R.string.widget_metric_network
                }
            )
        }
        return findViewById<Spinner>(R.id.metric_spinner).apply {
            adapter = ArrayAdapter(
                this@WidgetConfigureActivity,
                android.R.layout.simple_spinner_dropdown_item,
                labels,
            )
            setSelection(WidgetMetric.entries.indexOf(existing.metric).coerceAtLeast(0))
        }
    }
}
