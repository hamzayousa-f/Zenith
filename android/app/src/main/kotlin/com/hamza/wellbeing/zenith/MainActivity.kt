package com.hamza.wellbeing.zenith

import android.app.AppOpsManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.os.Process
import android.provider.Settings
import android.util.Base64
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.Calendar

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.hamza.wellbeing.zenith/usage"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkUsagePermission" -> {
                    result.success(hasUsageStatsPermission())
                }
                "openPermissionSettings" -> {
                    val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                    startActivity(intent)
                    result.success(true)
                }
                "getDailyAppUsage" -> {
                    if (hasUsageStatsPermission()) {
                        result.success(fetchDailyUsageData())
                    } else {
                        result.error("PERMISSION_DENIED", "Usage statistics permission not granted.", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun hasUsageStatsPermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = appOps.noteOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            Process.myUid(),
                                        packageName
        )
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun fetchDailyUsageData(): List<Map<String, Any>> {
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val pm = packageManager

        val calendar = Calendar.getInstance()
        val endTime = calendar.timeInMillis

        calendar.set(Calendar.HOUR_OF_DAY, 0)
        calendar.set(Calendar.MINUTE, 0)
        calendar.set(Calendar.SECOND, 0)
        calendar.set(Calendar.MILLISECOND, 0)
        val startTime = calendar.timeInMillis

        val stats = usageStatsManager.queryUsageStats(
            UsageStatsManager.INTERVAL_DAILY,
            startTime,
            endTime
        )

        val aggregatedStats = HashMap<String, Long>()
        if (stats != null) {
            for (usageStat in stats) {
                val totalTime = usageStat.totalTimeInForeground
                if (totalTime > 0) {
                    val pkgName = usageStat.packageName
                    if (!pkgName.contains("com.android.launcher") && !pkgName.contains("com.android.systemui")) {
                        aggregatedStats[pkgName] = (aggregatedStats[pkgName] ?: 0L) + totalTime
                    }
                }
            }
        }

        val usageList = ArrayList<Map<String, Any>>()

        for ((pkgName, timeSpent) in aggregatedStats) {
            val appData = HashMap<String, Any>()
            appData["packageName"] = pkgName
            appData["usageTime"] = timeSpent

            try {
                val appInfo = pm.getApplicationInfo(pkgName, 0)
                appData["appName"] = pm.getApplicationLabel(appInfo).toString()

                // Get App Icon and transform into Base64 format string safely
                val iconDrawable = pm.getApplicationIcon(appInfo)
                val base64Icon = drawableToBase64(iconDrawable)
                appData["appIcon"] = base64Icon
            } catch (e: PackageManager.NameNotFoundException) {
                appData["appName"] = pkgName.split(".").last()
                appData["appIcon"] = ""
            }
            usageList.add(appData)
        }
        return usageList
    }

    private fun drawableToBase64(drawable: Drawable): String {
        val bitmap = if (drawable is BitmapDrawable) {
            drawable.bitmap
        } else {
            val width = if (drawable.intrinsicWidth > 0) drawable.intrinsicWidth else 100
            val height = if (drawable.intrinsicHeight > 0) drawable.intrinsicHeight else 100
            val bmp = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bmp)
            drawable.setBounds(0, 0, canvas.width, canvas.height)
            drawable.draw(canvas)
            bmp
        }

        val outputStream = ByteArrayOutputStream()
        // Compress heavily to maintain fast execution pipelines over method channel data pipes
        bitmap.compress(Bitmap.CompressFormat.PNG, 80, outputStream)
        val byteArray = outputStream.toByteArray()
        return Base64.encodeToString(byteArray, Base64.NO_WRAP)
    }
}
