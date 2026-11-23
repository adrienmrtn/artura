package com.vikstudios.artura.services

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.vikstudios.artura.R
import com.vikstudios.artura.app.MainActivity
import com.vikstudios.artura.core.AppLanguage
import com.vikstudios.artura.core.L
import java.util.Calendar

/** Daily reminder and end-of-trial notice (local notifications, like iOS). */
object Reminder {
    private const val channelId = "artura.daily"
    private const val dailyCode = 1
    private const val trialCode = 2
    private const val prefsKey = "artura.reminder.minutes"

    /** Android 13+ asks for the permission at run time; the screen calls `PermissionRequester` and reports the answer here. */
    fun isAllowed(context: Context): Boolean =
        Build.VERSION.SDK_INT < 33 ||
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED

    private fun ensureChannel(context: Context) {
        val manager = context.getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(NotificationChannel(channelId, L("Daily reminder"), NotificationManager.IMPORTANCE_DEFAULT))
    }

    private fun pending(context: Context, kind: String, code: Int): PendingIntent =
        PendingIntent.getBroadcast(context, code, Intent(context, ReminderReceiver::class.java).putExtra("kind", kind),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

    /** Schedules the daily notification at the chosen time (minutes since midnight). */
    fun scheduleDaily(context: Context, minutes: Int) {
        context.getSharedPreferences("artura", Context.MODE_PRIVATE).edit().putInt(prefsKey, minutes).apply()
        val alarms = context.getSystemService(AlarmManager::class.java)
        val next = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, minutes / 60)
            set(Calendar.MINUTE, minutes % 60)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            if (timeInMillis <= System.currentTimeMillis()) add(Calendar.DAY_OF_YEAR, 1)
        }
        alarms.setRepeating(AlarmManager.RTC_WAKEUP, next.timeInMillis, AlarmManager.INTERVAL_DAY, pending(context, "daily", dailyCode))
    }

    fun cancelDaily(context: Context) {
        context.getSharedPreferences("artura", Context.MODE_PRIVATE).edit().remove(prefsKey).apply()
        context.getSystemService(AlarmManager::class.java).cancel(pending(context, "daily", dailyCode))
    }

    /** Notifies one day before the free trial ends (3 days by default). */
    fun scheduleTrialEnding(context: Context, trialDays: Int = 3) {
        val alarms = context.getSystemService(AlarmManager::class.java)
        val at = System.currentTimeMillis() + maxOf(1, trialDays - 1) * 24L * 3600 * 1000
        alarms.set(AlarmManager.RTC_WAKEUP, at, pending(context, "trial", trialCode))
    }

    /** After a reboot, alarms are gone: put the daily one back. */
    fun restore(context: Context) {
        val prefs = context.getSharedPreferences("artura", Context.MODE_PRIVATE)
        if (prefs.contains(prefsKey)) scheduleDaily(context, prefs.getInt(prefsKey, 510))
    }

    fun show(context: Context, kind: String) {
        AppLanguage.init(context)
        ensureChannel(context)
        if (!isAllowed(context)) return
        val (title, body) = if (kind == "trial")
            L("Your free trial ends tomorrow") to L("Keep going with Artura Pro, or cancel in one tap.")
        else
            L("Your artwork of the day is waiting") to L("Five minutes to look, understand, and remember.")
        val open = PendingIntent.getActivity(context, 0, Intent(context, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP), PendingIntent.FLAG_IMMUTABLE)
        val notification = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true)
            .setContentIntent(open)
            .build()
        try {
            NotificationManagerCompat.from(context).notify(if (kind == "trial") trialCode else dailyCode, notification)
        } catch (_: SecurityException) {}
    }
}

class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED -> Reminder.restore(context)
            else -> Reminder.show(context, intent.getStringExtra("kind") ?: "daily")
        }
    }
}
