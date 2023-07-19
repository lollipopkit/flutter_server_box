package tech.lolli.toolbox.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews
import kotlinx.coroutines.DelicateCoroutinesApi
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.launch
import org.json.JSONObject
import tech.lolli.toolbox.R
import java.net.URL

class HomeWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    @OptIn(DelicateCoroutinesApi::class)
    private fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
        val views = RemoteViews(context.packageName, R.layout.home_widget)
        val sp = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        var url = sp.getString("$appWidgetId", null)
        val gUrl = sp.getString("*", null)
        if (url.isNullOrEmpty()) {
            url = gUrl
        }

        val intentUpdate = Intent(context, HomeWidget::class.java)
        intentUpdate.action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
        val ids = intArrayOf(appWidgetId)
        intentUpdate.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)

        val pendingUpdate: PendingIntent = PendingIntent.getBroadcast(
                context,
                appWidgetId,
                intentUpdate,
                PendingIntent.FLAG_UPDATE_CURRENT)
        views.setOnClickPendingIntent(R.id.widget_container, pendingUpdate)

        if (url.isNullOrEmpty()) {
            views.setViewVisibility(R.id.widget_cpu_label, View.INVISIBLE)
            views.setViewVisibility(R.id.widget_mem_label, View.INVISIBLE)
            views.setViewVisibility(R.id.widget_disk_label, View.INVISIBLE)
            views.setViewVisibility(R.id.widget_net_label, View.INVISIBLE)
            views.setTextViewText(R.id.widget_name, "ID: $appWidgetId")
            appWidgetManager.updateAppWidget(appWidgetId, views)
            return
        }

        GlobalScope.launch(Dispatchers.IO) {
            val jsonStr = URL(url).readText()
            val jsonObject = JSONObject(jsonStr)
            val data = jsonObject.getJSONObject("data")
            val server = data.getString("name")
            val cpu = data.getString("cpu")
            val mem = data.getString("mem")
            val disk = data.getString("disk")
            val net = data.getString("net")

            GlobalScope.launch(Dispatchers.Main) {
                // mem or disk is empty -> get status failed
                // (cpu | net) isEmpty -> data is not ready
                if (mem.isEmpty() || disk.isEmpty()) {
                    return@launch
                }
                views.setTextViewText(R.id.widget_name, server)

                views.setTextViewText(R.id.widget_cpu, cpu)
                views.setTextViewText(R.id.widget_mem, mem)
                views.setTextViewText(R.id.widget_disk, disk)
                views.setTextViewText(R.id.widget_net, net)

                // eg: 17:17
                val timeStr = android.text.format.DateFormat.format("HH:mm", java.util.Date()).toString()
                views.setTextViewText(R.id.widget_time, timeStr)

                appWidgetManager.updateAppWidget(appWidgetId, views)
            }
        }
    }
}