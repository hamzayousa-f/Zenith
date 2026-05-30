package com.hamza.wellbeing.zenith

import android.app.AppOpsManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
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
        private var appLimitsMap = HashMap<String, Long>()
        private var temporarilyAllowedApps = HashMap<String, Long>()
        private var channelInstance: MethodChannel? = null

            // High-performance static memory cache for metadata and icons
            companion object {
                private val appLabelCache = HashMap<String, String>()
                private val appIconCache = HashMap<String, String>()
                private val dynamicRegistry = HashMap<String, ApplicationInfo>()
            }

            override fun onCreate(savedInstanceState: Bundle?) {
                super.onCreate(savedInstanceState)
                loadBlockedAppsFromNativeStorage()
                MidnightResetReceiver.scheduleMidnightReset(this)

                if (hasUsageStatsPermission() && (blockedAppsSet.isNotEmpty() || appLimitsMap.isNotEmpty())) {
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
                            val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        }
                        "checkOverlayPermission" -> result.success(Settings.canDrawOverlays(this))
                        "openOverlaySettings" -> {
                            val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        }
                        "syncBlockedApps" -> {
                            blockedAppsSet = HashSet(call.argument<List<String>>("apps") ?: listOf())
                            if (hasUsageStatsPermission()) startBlockerEngineLoop()
                                result.success(true)
                        }
                        "syncAppLimits" -> {
                            val limits = call.argument<Map<String, Int>>("limits") ?: mapOf()
                            appLimitsMap.clear()
                            for ((key, value) in limits) {
                                appLimitsMap[key] = value.toLong() * 60 * 1000
                            }
                            if (hasUsageStatsPermission()) startBlockerEngineLoop()
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
                                result.error("INVALID_PACKAGE", "Empty identifier", null)
                            }
                        }
                        "getDailyAppUsage" -> {
                            if (hasUsageStatsPermission()) {
                                Thread {
                                    // 1. Process usage records safely on worker background thread
                                    val rawStats = fetchRawUsageMap()

                                    // 2. Refresh basic app listing registry safely in background if empty
                                    if (dynamicRegistry.isEmpty()) {
                                        try {
                                            val installedApps = packageManager.getInstalledApplications(PackageManager.GET_META_DATA)
                                            for (app in installedApps) {
                                                dynamicRegistry[app.packageName] = app
                                            }
                                        } catch (e: Exception) {}
                                    }

                                    // 3. Resolve metadata details using our cache on the worker thread safely!
                                    val processedData = resolveAppDetailsWithMemoryCache(rawStats)

                                    // 4. Send the fully constructed data back to Flutter instantly on Main Thread
                                    Handler(Looper.getMainLooper()).post {
                                        result.success(processedData)
                                    }
                                }.start()
                            } else {
                                result.success(emptyList<Map<String, Any>>())
                            }
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
                    val sharedPrefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                    val jsonString = sharedPrefs.getString("flutter.blocked_apps", null)
                    if (jsonString != null) {
                        val clean = jsonString.replace("[", "").replace("]", "").replace("\"", "")
                        if (clean.isNotEmpty()) {
                            blockedAppsSet = HashSet(clean.split(",").map { it.trim() })
                        }
                    }

                    val limitsJson = sharedPrefs.getString("flutter.app_limits_minutes", null)
                    if (limitsJson != null) {
                        val clean = limitsJson.replace("{", "").replace("}", "").replace("\"", "")
                        if (clean.isNotEmpty()) {
                            val pairs = clean.split(",")
                            for (pair in pairs) {
                                val splitPair = pair.split(":")
                                if (splitPair.size == 2) {
                                    val pkg = splitPair[0].trim()
                                    val mins = splitPair[1].trim().toLongOrNull() ?: 0L
                                    if (mins > 0) appLimitsMap[pkg] = mins * 60 * 1000
                                }
                            }
                        }
                    }
                } catch (e: Exception) { e.printStackTrace() }
            }

            private fun startBlockerEngineLoop() {
                if (blockerHandler != null) return
                    blockerHandler = Handler(Looper.getMainLooper())
                    blockerHandler?.post(object : Runnable {
                        override fun run() {
                            if (!hasUsageStatsPermission()) {
                                blockerHandler?.postDelayed(this, 1000)
                                return
                            }

                            val currentTopPackage = getTopPackageName()
                            val currentTime = System.currentTimeMillis()
                            val dailyStatsMap = getTodayUsageMap()
                            val accumulatedTime = dailyStatsMap[currentTopPackage] ?: 0L
                            val allowedLimit = appLimitsMap[currentTopPackage] ?: Long.MAX_VALUE
                            val isExplicitlyBlocked = blockedAppsSet.contains(currentTopPackage)
                            val isLimitExceeded = accumulatedTime > allowedLimit

                            if (isExplicitlyBlocked || isLimitExceeded) {
                                val allowedUntil = temporarilyAllowedApps[currentTopPackage] ?: 0L
                                if (currentTime > allowedUntil || isLimitExceeded) {
                                    var appLabel = currentTopPackage
                                    synchronized(appLabelCache) {
                                        if (appLabelCache.containsKey(currentTopPackage)) {
                                            appLabel = appLabelCache[currentTopPackage] ?: currentTopPackage
                                        } else {
                                            try {
                                                val appInfo = packageManager.getApplicationInfo(currentTopPackage, 0)
                                                appLabel = packageManager.getApplicationLabel(appInfo).toString()
                                                appLabelCache[currentTopPackage] = appLabel
                                            } catch (e: Exception) {}
                                        }
                                    }

                                    val intent = Intent(this@MainActivity, MainActivity::class.java).apply {
                                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                                    }
                                    startActivity(intent)

                                    val violationType = if (isLimitExceeded) "limit_exceeded" else "hard_block"
                                    val payload = mapOf(
                                        "appName" to appLabel,
                                        "packageName" to currentTopPackage,
                                        "violationType" to violationType
                                    )
                                    channelInstance?.invokeMethod("triggerNativeShield", payload)
                                }
                            }
                            blockerHandler?.postDelayed(this, 500)
                        }
                    })
            }

            private fun getTopPackageName(): String {
                val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
                val time = System.currentTimeMillis()
                val stats = usageStatsManager.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, time - 10000, time)
                if (stats != null && stats.isNotEmpty()) {
                    return stats.sortedByDescending { it.lastTimeUsed }[0].packageName
                }
                return ""
            }

            private fun getTodayUsageMap(): Map<String, Long> {
                val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
                val calendar = Calendar.getInstance()
                val endTime = calendar.timeInMillis
                calendar.set(Calendar.HOUR_OF_DAY, 0); calendar.set(Calendar.MINUTE, 0); calendar.set(Calendar.SECOND, 0)
                val startTime = calendar.timeInMillis

                val stats = usageStatsManager.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, startTime, endTime)
                val usageMap = HashMap<String, Long>()
                if (stats != null) {
                    for (stat in stats) {
                        usageMap[stat.packageName] = (usageMap[stat.packageName] ?: 0L) + stat.totalTimeInForeground
                    }
                }
                return usageMap
            }

            private fun fetchRawUsageMap(): Map<String, Long> {
                val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
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
                return aggregatedStats
            }

            private fun resolveAppDetailsWithMemoryCache(rawStats: Map<String, Long>): List<Map<String, Any>> {
                val pm = packageManager
                val usageList = ArrayList<Map<String, Any>>()
                val sortedAppsList = rawStats.toList().sortedByDescending { it.second }

                for ((pkgName, timeSpent) in sortedAppsList) {
                    val appData = HashMap<String, Any>()
                    appData["packageName"] = pkgName
                    appData["usageTime"] = timeSpent

                    var resolvedName: String
                    var resolvedIconBase64: String

                    // Thread-safe isolation check over cache metrics maps
                    synchronized(appLabelCache) {
                        if (appLabelCache.containsKey(pkgName)) {
                            resolvedName = appLabelCache[pkgName] ?: ""
                            resolvedIconBase64 = appIconCache[pkgName] ?: ""
                        } else {
                            // Cache Miss: Perform lookups safely on this background thread container
                            val appInfo = dynamicRegistry[pkgName]
                            if (appInfo != null) {
                                try {
                                    resolvedName = pm.getApplicationLabel(appInfo).toString()
                                    resolvedIconBase64 = drawableToBase64(pm.getApplicationIcon(appInfo))
                                } catch (e: Exception) {
                                    resolvedName = fallbackFormattedName(pkgName)
                                    resolvedIconBase64 = ""
                                }
                            } else {
                                try {
                                    val fallbackInfo = pm.getApplicationInfo(pkgName, 0)
                                    resolvedName = pm.getApplicationLabel(fallbackInfo).toString()
                                    resolvedIconBase64 = drawableToBase64(pm.getApplicationIcon(fallbackInfo))
                                } catch (e: Exception) {
                                    resolvedName = fallbackFormattedName(pkgName)
                                    resolvedIconBase64 = ""
                                }
                            }
                            // Commit to long-term memory allocation structures
                            if (resolvedName.isNotEmpty()) appLabelCache[pkgName] = resolvedName
                                appIconCache[pkgName] = resolvedIconBase64
                        }
                    }

                    appData["appName"] = resolvedName
                    appData["appIcon"] = resolvedIconBase64
                    usageList.add(appData)
                }
                return usageList
            }

            private fun fallbackFormattedName(pkgName: String): String {
                val components = pkgName.split(".")
                val rawLeaf = components.last()
                return if (rawLeaf.equals("android", ignoreCase = true) && components.size > 1) {
                    components[components.size - 2].replaceFirstChar { it.uppercase() }
                } else {
                    rawLeaf.replaceFirstChar { it.uppercase() }
                }
            }

            private fun drawableToBase64(drawable: Drawable): String {
                val bitmap = if (drawable is BitmapDrawable) {
                    drawable.bitmap
                } else {
                    val width = if (drawable.intrinsicWidth > 0) drawable.intrinsicWidth else 72
                    val height = if (drawable.intrinsicHeight > 0) drawable.intrinsicHeight else 72
                    val bmp = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                    val canvas = Canvas(bmp)
                    drawable.setBounds(0, 0, canvas.width, canvas.height)
                    drawable.draw(canvas)
                    bmp
                }
                val outputStream = ByteArrayOutputStream()
                bitmap.compress(Bitmap.CompressFormat.PNG, 80, outputStream) // Dropped to 80% to vastly compress MethodChannel transfer load bandwidth
                return Base64.encodeToString(outputStream.toByteArray(), Base64.NO_WRAP)
            }
}
