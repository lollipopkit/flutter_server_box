package tech.lolli.toolbox.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONObject
import tech.lolli.toolbox.R
import java.net.URL
import java.net.HttpURLConnection
import java.io.FileNotFoundException

class HomeWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

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

        if (url.isNullOrEmpty()) {
            Log.e("HomeWidget", "URL not found")
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
            views.setTextViewText(R.id.widget_name, "No URL")
            // Update the widget to display a message for missing URL
            views.setViewVisibility(R.id.error_message, View.VISIBLE)
            views.setTextViewText(R.id.error_message, "Please configure the widget URL.")
            views.setViewVisibility(R.id.widget_content, View.GONE)
            views.setFloat(R.id.widget_name, "setAlpha", 1f)
            views.setFloat(R.id.error_message, "setAlpha", 1f)
            appWidgetManager.updateAppWidget(appWidgetId, views)
            return
        } else {
            views.setViewVisibility(R.id.widget_cpu_label, View.VISIBLE)
            views.setViewVisibility(R.id.widget_mem_label, View.VISIBLE)
            views.setViewVisibility(R.id.widget_disk_label, View.VISIBLE)
            views.setViewVisibility(R.id.widget_net_label, View.VISIBLE)
        }

        CoroutineScope(Dispatchers.IO).launch {
            try {
                val connection = URL(url).openConnection() as HttpURLConnection
                connection.requestMethod = "GET"
                val responseCode = connection.responseCode
                if (responseCode == HttpURLConnection.HTTP_OK) {
                    val jsonStr = connection.inputStream.bufferedReader().use { it.readText() }
                    val jsonObject = JSONObject(jsonStr)
                    val data = jsonObject.getJSONObject("data")
                    val server = data.getString("name")
                    val cpu = data.getString("cpu")
                    val mem = data.getString("mem")
                    val disk = data.getString("disk")
                    val net = data.getString("net")
                    withContext(Dispatchers.Main) {
                        if (mem.isEmpty() || disk.isEmpty()) {
                            Log.e("HomeWidget", "Failed to retrieve status: Memory or disk information is empty")
                            return@withContext
                        }
                        views.setTextViewText(R.id.widget_name, server)
                        views.setTextViewText(R.id.widget_cpu, cpu)
                        views.setTextViewText(R.id.widget_mem, mem)
                        views.setTextViewText(R.id.widget_disk, disk)
                        views.setTextViewText(R.id.widget_net, net)
                        val timeStr = android.text.format.DateFormat.format("HH:mm", java.util.Date()).toString()
                        views.setTextViewText(R.id.widget_time, timeStr)
                        views.setFloat(R.id.widget_name, "setAlpha", 1f)
                        views.setFloat(R.id.widget_cpu_label, "setAlpha", 1f)
                        views.setFloat(R.id.widget_mem_label, "setAlpha", 1f)
                        views.setFloat(R.id.widget_disk_label, "setAlpha", 1f)
                        views.setFloat(R.id.widget_net_label, "setAlpha", 1f)
                        views.setFloat(R.id.widget_time, "setAlpha", 1f)
                        appWidgetManager.updateAppWidget(appWidgetId, views)
                    }
                } else {
                    throw FileNotFoundException("HTTP response code: $responseCode")
                }
            } catch (e: Exception) {
                Log.e("HomeWidget", "Error updating widget: ${e.localizedMessage}", e)
                withContext(Dispatchers.Main) {
                    views.setTextViewText(R.id.widget_name, "Error")
                    // Update the widget to display a message for data retrieval failure
                    views.setViewVisibility(R.id.error_message, View.VISIBLE)
                    views.setTextViewText(R.id.error_message, "Failed to retrieve data.")
                    views.setViewVisibility(R.id.widget_content, View.GONE)
                    views.setFloat(R.id.widget_name, "setAlpha", 1f)
                    views.setFloat(R.id.error_message, "setAlpha", 1f)
                    appWidgetManager.updateAppWidget(appWidgetId, views)
                }
            }
        }
    }
}