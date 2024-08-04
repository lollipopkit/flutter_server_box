package tech.lolli.toolbox.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.os.Build
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
        var url = sp.getString("widget_$appWidgetId", null)
        if (url.isNullOrEmpty()) {
            url = sp.getString("$appWidgetId", null)
        }
        if (url.isNullOrEmpty()) {
            val gUrl = sp.getString("widget_*", null)
            url = gUrl
        }

        val intentUpdate = Intent(context, HomeWidget::class.java)
        intentUpdate.action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
        val ids = intArrayOf(appWidgetId)
        intentUpdate.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)

        var flag = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION_CODES.O <= Build.VERSION.SDK_INT) {    
            flag = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        }

        val pendingUpdate: PendingIntent = PendingIntent.getBroadcast(
                context,
                appWidgetId,
                intentUpdate,
                flag)
        views.setOnClickPendingIntent(R.id.widget_container, pendingUpdate)

        if (url.isNullOrEmpty()) {
            views.setViewVisibility(R.id.widget_cpu_label, View.INVISIBLE)
            views.setViewVisibility(R.id.widget_mem_label, View.INVISIBLE)
            views.setViewVisibility(R.id.widget_disk_label, View.INVISIBLE)
            views.setViewVisibility(R.id.widget_net_label, View.INVISIBLE)
            views.setTextViewText(R.id.widget_name, "ID: $appWidgetId")
            appWidgetManager.updateAppWidget(appWidgetId, views)
            return
        } else {
            views.setViewVisibility(R.id.widget_cpu_label, View.VISIBLE)
            views.setViewVisibility(R.id.widget_mem_label, View.VISIBLE)
            views.setViewVisibility(R.id.widget_disk_label, View.VISIBLE)
            views.setViewVisibility(R.id.widget_net_label, View.VISIBLE)
        }

        GlobalScope.launch(Dispatchers.IO) {
            try {
                val jsonStr = URL(url).readText()
                val jsonObject = JSONObject(jsonStr)
                val data = jsonObject.getJSONObject("data")
                val server = data.getString("name")
                val cpu = data.getString("cpu")
                val mem = data.getString("mem")
                val disk = data.getString("disk")
                val net = data.getString("net")

                GlobalScope.launch(Dispatchers.Main) main@ {
                    // mem or disk is empty -> get status failed
                    // (cpu | net) isEmpty -> data is not ready
                    if (mem.isEmpty() || disk.isEmpty()) {
                        return@main
                    }
                    views.setTextViewText(R.id.widget_name, server)

                    views.setTextViewText(R.id.widget_cpu, cpu)
                    views.setTextViewText(R.id.widget_mem, mem)
                    views.setTextViewText(R.id.widget_disk, disk)
                    views.setTextViewText(R.id.widget_net, net)

                    val timeStr = android.text.format.DateFormat.format("HH:mm", java.util.Date()).toString()
                    views.setTextViewText(R.id.widget_time, timeStr)

                    appWidgetManager.updateAppWidget(appWidgetId, views)
                }
            } catch (e: Exception) {
                println("ServerBoxHomeWidget: ${e.localizedMessage}")
                GlobalScope.launch(Dispatchers.Main) main@ {
                    views.setViewVisibility(R.id.widget_cpu_label, View.INVISIBLE)
                    views.setViewVisibility(R.id.widget_mem_label, View.INVISIBLE)
                    views.setViewVisibility(R.id.widget_disk_label, View.INVISIBLE)
                    views.setViewVisibility(R.id.widget_net_label, View.INVISIBLE)
                    views.setTextViewText(R.id.widget_name, "ID: $appWidgetId")
                    views.setTextViewText(R.id.widget_mem, e.localizedMessage)
                    appWidgetManager.updateAppWidget(appWidgetId, views)
                }
            }
        }
    }
}