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
import kotlinx.coroutines.withTimeoutOrNull
import org.json.JSONObject
import org.json.JSONException
import tech.lolli.toolbox.R
import java.net.URL
import java.net.HttpURLConnection
import java.net.SocketTimeoutException
import java.io.FileNotFoundException
import java.io.IOException
import java.util.concurrent.ConcurrentHashMap

class HomeWidget : AppWidgetProvider() {
    companion object {
        private const val TAG = "HomeWidget"
        private const val NETWORK_TIMEOUT = 10_000L // 10 seconds
        private const val COROUTINE_TIMEOUT = 15_000L // 15 seconds
        private val activeUpdates = ConcurrentHashMap<Int, Boolean>()
    }
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    private fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
        // Prevent concurrent updates for the same widget
        if (activeUpdates.putIfAbsent(appWidgetId, true) == true) {
            Log.d(TAG, "Widget $appWidgetId is already updating, skipping")
            return
        }

        val views = RemoteViews(context.packageName, R.layout.home_widget)
        val url = getWidgetUrl(context, appWidgetId)

        if (url.isNullOrEmpty()) {
            Log.w(TAG, "URL not found for widget $appWidgetId")
            showErrorState(views, appWidgetManager, appWidgetId, "Please configure the widget URL.")
            activeUpdates.remove(appWidgetId)
            return
        }

        setupClickIntent(context, views, appWidgetId)

        showLoadingState(views, appWidgetManager, appWidgetId)

        CoroutineScope(Dispatchers.IO).launch {
            withTimeoutOrNull(COROUTINE_TIMEOUT) {
                try {
                    val serverData = fetchServerData(url)
                    if (serverData != null) {
                        withContext(Dispatchers.Main) {
                            showSuccessState(views, appWidgetManager, appWidgetId, serverData)
                        }
                    } else {
                        withContext(Dispatchers.Main) {
                            showErrorState(views, appWidgetManager, appWidgetId, "Invalid server data received.")
                        }
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error updating widget $appWidgetId: ${e.message}", e)
                    withContext(Dispatchers.Main) {
                        val errorMessage = when (e) {
                            is SocketTimeoutException -> "Connection timeout. Please check your network."
                            is IOException -> "Network error. Please check your connection."
                            is JSONException -> "Invalid data format received from server."
                            else -> "Failed to retrieve data: ${e.message}"
                        }
                        showErrorState(views, appWidgetManager, appWidgetId, errorMessage)
                    }
                }
            } ?: run {
                Log.w(TAG, "Widget update timed out for widget $appWidgetId")
                withContext(Dispatchers.Main) {
                    showErrorState(views, appWidgetManager, appWidgetId, "Update timed out. Please try again.")
                }
            }
            activeUpdates.remove(appWidgetId)
        }
    }

    private fun getWidgetUrl(context: Context, appWidgetId: Int): String? {
        val sp = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        return sp.getString("widget_$appWidgetId", null)
            ?: sp.getString("$appWidgetId", null)
            ?: sp.getString("widget_*", null)
    }

    private fun setupClickIntent(context: Context, views: RemoteViews, appWidgetId: Int) {
        val intentConfigure = Intent(context, WidgetConfigureActivity::class.java).apply {
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
        }

        val flag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        val pendingConfigure = PendingIntent.getActivity(context, appWidgetId, intentConfigure, flag)
        views.setOnClickPendingIntent(R.id.widget_container, pendingConfigure)
    }

    private suspend fun fetchServerData(url: String): ServerData? = withContext(Dispatchers.IO) {
        var connection: HttpURLConnection? = null
        try {
            connection = (URL(url).openConnection() as HttpURLConnection).apply {
                requestMethod = "GET"
                connectTimeout = NETWORK_TIMEOUT.toInt()
                readTimeout = NETWORK_TIMEOUT.toInt()
                setRequestProperty("User-Agent", "ServerBox-Widget/1.0")
                setRequestProperty("Accept", "application/json")
            }

            if (connection.responseCode != HttpURLConnection.HTTP_OK) {
                throw IOException("HTTP ${connection.responseCode}: ${connection.responseMessage}")
            }

            val jsonStr = connection.inputStream.bufferedReader().use { it.readText() }
            parseServerData(jsonStr)
        } finally {
            connection?.disconnect()
        }
    }

    private fun parseServerData(jsonStr: String): ServerData? {
        return try {
            val jsonObject = JSONObject(jsonStr)
            val data = jsonObject.getJSONObject("data")
            
            val server = data.optString("name", "Unknown Server")
            val cpu = data.optString("cpu", "").takeIf { it.isNotBlank() } ?: "N/A"
            val mem = data.optString("mem", "").takeIf { it.isNotBlank() } ?: "N/A"
            val disk = data.optString("disk", "").takeIf { it.isNotBlank() } ?: "N/A"
            val net = data.optString("net", "").takeIf { it.isNotBlank() } ?: "N/A"
            
            // Return data even if some fields are missing, providing defaults
            // Only reject if we can't parse the JSON structure properly
            ServerData(server, cpu, mem, disk, net)
        } catch (e: JSONException) {
            Log.e(TAG, "JSON parsing error: ${e.message}", e)
            null
        }
    }

    private fun showLoadingState(views: RemoteViews, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
        views.apply {
            setTextViewText(R.id.widget_name, "Loading...")
            setViewVisibility(R.id.error_message, View.GONE)
            setViewVisibility(R.id.widget_content, View.VISIBLE)
            setViewVisibility(R.id.widget_cpu_label, View.VISIBLE)
            setViewVisibility(R.id.widget_mem_label, View.VISIBLE)
            setViewVisibility(R.id.widget_disk_label, View.VISIBLE)
            setViewVisibility(R.id.widget_net_label, View.VISIBLE)
            setViewVisibility(R.id.widget_progress, View.VISIBLE)
            setFloat(R.id.widget_name, "setAlpha", 0.7f)
        }
        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    private fun showSuccessState(views: RemoteViews, appWidgetManager: AppWidgetManager, appWidgetId: Int, data: ServerData) {
        views.apply {
            setTextViewText(R.id.widget_name, data.name)
            setTextViewText(R.id.widget_cpu, data.cpu)
            setTextViewText(R.id.widget_mem, data.mem)
            setTextViewText(R.id.widget_disk, data.disk)
            setTextViewText(R.id.widget_net, data.net)
            
            val timeStr = android.text.format.DateFormat.format("HH:mm", java.util.Date()).toString()
            setTextViewText(R.id.widget_time, timeStr)
            
            setViewVisibility(R.id.error_message, View.GONE)
            setViewVisibility(R.id.widget_content, View.VISIBLE)
            setViewVisibility(R.id.widget_progress, View.GONE)
            
            // Smooth fade-in animation
            setFloat(R.id.widget_name, "setAlpha", 1f)
            setFloat(R.id.widget_cpu_label, "setAlpha", 1f)
            setFloat(R.id.widget_mem_label, "setAlpha", 1f)
            setFloat(R.id.widget_disk_label, "setAlpha", 1f)
            setFloat(R.id.widget_net_label, "setAlpha", 1f)
            setFloat(R.id.widget_time, "setAlpha", 1f)
        }
        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    private fun showErrorState(views: RemoteViews, appWidgetManager: AppWidgetManager, appWidgetId: Int, errorMessage: String) {
        views.apply {
            setTextViewText(R.id.widget_name, "Error")
            setViewVisibility(R.id.error_message, View.VISIBLE)
            setTextViewText(R.id.error_message, errorMessage)
            setViewVisibility(R.id.widget_content, View.GONE)
            setViewVisibility(R.id.widget_progress, View.GONE)
            setFloat(R.id.widget_name, "setAlpha", 1f)
            setFloat(R.id.error_message, "setAlpha", 1f)
        }
        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    data class ServerData(
        val name: String,
        val cpu: String,
        val mem: String,
        val disk: String,
        val net: String
    )
}