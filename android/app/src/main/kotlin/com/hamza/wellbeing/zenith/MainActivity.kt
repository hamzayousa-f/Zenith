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
import android.os.Bundle
import android.os.Handler
import android.os.Looper
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
    private var blockerHandler: Handler? = null
        private var blockedAppsSet = HashSet<String>()
        private var temporarilyAllowedApps = HashMap<String, Long>()
        private var channelInstance: MethodChannel? = null

            override fun onCreate(savedInstanceState: Bundle?) {
                super.onCreate(savedInstanceState)
                // If revived by a cold hardware boot, retrieve restrictions natively and start up loops immediately
                loadBlockedAppsFromNativeStorage()
                if (blockedAppsSet.isNotEmpty()) {
                    startBlockerEngineLoop()
                }
            }

            override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
                super.configureFlutterEngine(flutterEngine)

                channelInstance = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
                channelInstance?.setMethodCallHandler { call, result ->
                    when (call.method) {
                        "checkUsagePermission" -> result.success(hasUsageStatsPermission())
                        "openPermissionSettings" -> {
                            startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                            result.success(true)
                        }
                        "checkOverlayPermission" -> result.success(Settings.canDrawOverlays(this))
                        "openOverlaySettings" -> {
                            startActivity(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION))
                            result.success(true)
                        }
                        "syncBlockedApps" -> {
                            val appsList = call.argument<List<String>>("apps") ?: listOf()
                            blockedAppsSet = HashSet(appsList)
                            if (blockedAppsSet.isNotEmpty() && blockerHandler == null) {
                                startBlockerEngineLoop()
                            }
                            result.success(true)
                        }
                        "launchTargetApp" -> {
                            val pkgName = call.argument<String>("packageName") ?: ""
                            if (pkgName.isNotEmpty()) {
                                temporarilyAllowedApps[pkgName] = System.currentTimeMillis() + (10 * 60 * 1000)
                                val launchIntent = packageManager.getLaunchIntentForPackage(pkgName)
                                if (launchIntent != null) {
                                    startActivity(launchIntent)
                                    result.success(true)
                                } else {
                                    result.error("LAUNCH_FAILED", "Intent failure", null)
                                }
                            } else {
                                result.error("INVALID_PACKAGE", "Empty package identifier", null)
                            }
                        }
                        "getDailyAppUsage" -> {
                            if (hasUsageStatsPermission()) result.success(fetchDailyUsageData())
                                else result.error("PERMISSION_DENIED", "Permission denied.", null)
                        }
                        else -> result.notImplemented()
                    }
                }
            }

            private fun hasUsageStatsPermission(): Boolean {
                val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
                val mode = appOps.noteOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName)
                return mode == AppOpsManager.MODE_ALLOWED
            }

            private fun loadBlockedAppsFromNativeStorage() {
                try {
                    // Flutter's SharedPreferences plugin prefixes keys with 'Flutter.' inside standard XML data structures
                    val sharedPrefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                    val jsonString = sharedPrefs.getString("flutter.blocked_apps", null)
                    if (jsonString != null) {
                        // Parse out simple raw elements array manually for cold boot resilience
                        val clean = jsonString.replace("[", "").replace("]", "").replace("\"", "")
                        if (clean.isNotEmpty()) {
                            blockedAppsSet = HashSet(clean.split(",").map { it.trim() })
                        }
                    }
                } catch (e: Exception) { e.printStackTrace() }
            }

            private fun startBlockerEngineLoop() {
                if (blockerHandler != null) return
                    blockerHandler = Handler(Looper.getMainLooper())
                    blockerHandler?.post(object : Runnable {
                        override fun run() {
                            val currentTopPackage = getTopPackageName()
                            val currentTime = System.currentTimeMillis()

                            if (blockedAppsSet.contains(currentTopPackage)) {
                                val allowedUntil = temporarilyAllowedApps[currentTopPackage] ?: 0L
                                if (currentTime > allowedUntil) {
                                    val pm = packageManager
                                    var appLabel = currentTopPackage
                                    try {
                                        val appInfo = pm.getApplicationInfo(currentTopPackage, 0)
                                        appLabel = pm.getApplicationLabel(appInfo).toString()
                                    } catch (e: Exception) {}

                                    val intent = Intent(this@MainActivity, MainActivity::class.java).apply {
                                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                                    }
                                    startActivity(intent)

                                    val payload = mapOf("appName" to appLabel, "packageName" to currentTopPackage)
                                    newHandlerPost { channelInstance?.invokeMethod("triggerNativeShield", payload) }
                                }
                            }
                            blockerHandler?.postDelayed(this, 500)
                        }
                    })
            }

            private fun newHandlerPost(action: () -> Unit) {
                Handler(Looper.getMainLooper()).post { action() }
            }

            private fun getTopPackageName(): String {
                val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
                val time = System.currentTimeMillis()
                val stats = usageStatsManager.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, time - 10000, time)
                if (stats != null && stats.isNotEmpty()) {
                    val sortedStats = stats.sortedByDescending { it.lastTimeUsed }
                    return sortedStats[0].packageName
                }
                return ""
            }

            private fun drawableToBase64(drawable: Drawable): String {
                val bitmap = if (drawable is BitmapDrawable) drawable.bitmap else {
                    val bmp = Bitmap.createBitmap(100, 100, Bitmap.Config.ARGB_8888)
                    val canvas = Canvas(bmp)
                    drawable.setBounds(0, 0, canvas.width, canvas.height)
                    drawable.draw(canvas)
                    bmp
                }
                val outputStream = ByteArrayOutputStream()
                bitmap.compress(Bitmap.CompressFormat.PNG, 80, outputStream)
                return Base64.encodeToString(outputStream.toByteArray(), Base64.NO_WRAP)
            }

            private fun fetchDailyUsageData(): List<Map<String, Any>> {
                val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
                val pm = packageManager
                val calendar = Calendar.getInstance()
                val endTime = calendar.timeInMillis
                calendar.set(Calendar.HOUR_OF_DAY, 0); calendar.set(Calendar.MINUTE, 0); calendar.set(Calendar.SECOND, 0)
                val startTime = calendar.timeInMillis

                val stats = usageStatsManager.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, startTime, endTime)
                val aggregatedStats = HashMap<String, Long>()
                if (stats != null) {
                    for (usageStat in stats) {
                        val totalTime = usageStat.totalTimeInForeground
                        if (totalTime > 0) {
                            val pkgName = usageStat.packageName
                            if (!pkgName.contains("launcher") && !pkgName.contains("systemui") && pkgName != packageName) {
                                aggregatedStats[pkgName] = (aggregatedStats[pkgName] ?: 0L) + totalTime
                            }
                        }
                    }
                }

                val usageList = ArrayList<Map<String, Any>>()
                for ((pkgName, timeSpent) in aggregatedStats) {
                    val appData = HashMap<String, Any>()
                    appData["packageName"] = pkgName; appData["usageTime"] = timeSpent
                    try {
                        val appInfo = pm.getApplicationInfo(pkgName, 0)
                        appData["appName"] = pm.getApplicationLabel(appInfo).toString()
                        appData["appIcon"] = drawableToBase64(pm.getApplicationIcon(appInfo))
                    } catch (e: PackageManager.NameNotFoundException) {
                        appData["appName"] = pkgName.split(".").last(); appData["appIcon"] = ""
                    }
                    usageList.add(appData)
                }
                return usageList
            }
}
