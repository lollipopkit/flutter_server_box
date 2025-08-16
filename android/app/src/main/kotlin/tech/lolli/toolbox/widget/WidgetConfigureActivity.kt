package tech.lolli.toolbox.widget

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import android.widget.Button
import android.widget.EditText
import tech.lolli.toolbox.R

class WidgetConfigureActivity : Activity() {
    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID
    private lateinit var urlEditText: EditText
    private lateinit var saveButton: Button

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.widget_configure)

        // 设置结果为取消，以防用户在完成配置前退出
        setResult(RESULT_CANCELED)

        // 获取 widget ID
        val extras = intent.extras
        if (extras != null) {
            appWidgetId = extras.getInt(
                AppWidgetManager.EXTRA_APPWIDGET_ID,
                AppWidgetManager.INVALID_APPWIDGET_ID
            )
        }

        // 如果没有有效的 widget ID，完成 activity
        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }

        // 初始化 UI 元素
        urlEditText = findViewById(R.id.url_edit_text)
        saveButton = findViewById(R.id.save_button)

        // 从 SharedPreferences 加载现有配置
        val sp = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
        val existingUrl = sp.getString("widget_$appWidgetId", "")
        urlEditText.setText(existingUrl)

        // 设置保存按钮点击事件
        saveButton.setOnClickListener {
            val url = urlEditText.text.toString().trim()
            if (url.isNotEmpty()) {
                // 保存 URL 到 SharedPreferences
                val editor = sp.edit()
                editor.putString("widget_$appWidgetId", url)
                editor.apply()

                // 更新 widget
                val appWidgetManager = AppWidgetManager.getInstance(this)
                val homeWidget = HomeWidget()
                homeWidget.onUpdate(this, appWidgetManager, intArrayOf(appWidgetId))

                // 设置结果并结束 activity
                val resultValue = Intent()
                resultValue.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                setResult(RESULT_OK, resultValue)
                finish()
            } else {
                urlEditText.error = "Please enter a URL"
            }
        }
    }
}