package com.hamza.wellbeing.zenith

import android.app.AppOpsManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Process
import android.provider.Settings
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
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

    private fun fetchDailyUsageData(): Map<String, Long> {
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager

        // Calculate the timeframe boundary limits (From midnight today until right now)
        val calendar = Calendar.getInstance()
        val endTime = calendar.timeInMillis

        calendar.set(Calendar.HOUR_OF_DAY, 0)
        calendar.set(Calendar.MINUTE, 0)
        calendar.set(Calendar.SECOND, 0)
        calendar.set(Calendar.MILLISECOND, 0)
        val startTime = calendar.timeInMillis

        // Query the OS logs directly
        val stats = usageStatsManager.queryUsageStats(
            UsageStatsManager.INTERVAL_DAILY,
            startTime,
            endTime
        )

        val usageMap = HashMap<String, Long>()
        if (stats != null) {
            for (usageStat in stats) {
                val totalTime = usageStat.totalTimeInForeground
                if (totalTime > 0) {
                    // Extract clean human readable app identities
                    val pkgName = usageStat.packageName
                    // Standard clean up filter out system launchers or empty layers
                    if (!pkgName.contains("com.android.launcher") && !pkgName.contains("com.android.systemui")) {
                        usageMap[pkgName] = (usageMap[pkgName] ?: 0L) + totalTime
                    }
                }
            }
        }
        return usageMap
    }
}
