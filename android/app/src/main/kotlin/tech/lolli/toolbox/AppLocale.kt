package tech.lolli.toolbox

import android.app.LocaleManager
import android.content.Context
import android.os.Build
import android.os.LocaleList

/**
 * The per-app language (Android 13+), and what it held right after the app
 * last set it. A current value that differs from that one was chosen in
 * system settings, whether or not the app was running then.
 */
object AppLocale {
    private const val PREFS = "app_locale"
    private const val KEY_AGREED = "agreed"

    /** `{"current","agreed"}`; null below API 33. */
    fun read(context: Context): Map<String, String?>? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return null
        val lm = context.getSystemService(LocaleManager::class.java) ?: return null
        return mapOf(
            "current" to lm.applicationLocales.toLanguageTags(),
            "agreed" to prefs(context).getString(KEY_AGREED, null),
        )
    }

    fun set(context: Context, tags: String) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        val lm = context.getSystemService(LocaleManager::class.java) ?: return
        lm.applicationLocales = LocaleList.forLanguageTags(tags)
        // Read back rather than [tags]: the system normalizes what it is given.
        prefs(context).edit().putString(KEY_AGREED, lm.applicationLocales.toLanguageTags()).apply()
    }

    private fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}
