package tech.lolli.toolbox

import android.annotation.SuppressLint
import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService

/**
 * The Quick Settings tile: on while anything is connected, saying how many.
 *
 * Tapping it on does what the notification's "Stop All" does — the same
 * service action, so there is one path that ends every session. Tapping it
 * off opens the app.
 */
class SessionsTileService : TileService() {
    override fun onStartListening() {
        super.onStartListening()
        render()
    }

    override fun onClick() {
        super.onClick()
        if (ForegroundService.sessionCount > 0) {
            // Ending every session from the lock screen is not something a
            // passer-by should be able to do.
            if (isLocked) unlockAndRun { stopAll() } else stopAll()
        } else {
            openApp()
        }
    }

    private fun stopAll() {
        startService(
            Intent(this, ForegroundService::class.java).setAction(ForegroundService.ACTION_STOP_FOREGROUND),
        )
    }

    @SuppressLint("StartActivityAndCollapseDeprecated")
    private fun openApp() {
        val intent = Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startActivityAndCollapse(
                PendingIntent.getActivity(this, 0, intent, PendingIntent.FLAG_IMMUTABLE),
            )
        } else {
            @Suppress("DEPRECATION")
            startActivityAndCollapse(intent)
        }
    }

    private fun render() {
        val tile = qsTile ?: return
        val count = ForegroundService.sessionCount
        tile.state = if (count > 0) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
        tile.label = getString(R.string.app_name)
        val subtitle = if (count > 0) {
            resources.getQuantityString(R.plurals.tile_sessions, count, count)
        } else {
            getString(R.string.tile_no_sessions)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            tile.subtitle = subtitle
        }
        tile.contentDescription = "${tile.label}, $subtitle"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            tile.stateDescription = subtitle
        }
        tile.updateTile()
    }

    companion object {
        /** Asks the system to re-render the tile, if it is placed. */
        fun refresh(context: Context) {
            try {
                requestListeningState(context, ComponentName(context, SessionsTileService::class.java))
            } catch (e: Exception) {
                // Refused when the tile is not added; nothing to update then.
            }
        }
    }
}
