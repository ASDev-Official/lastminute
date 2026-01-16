package com.aadishsamir.lastminute

import android.app.AppOpsManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val APP_BLOCKER_CHANNEL = "com.lastminute/app_blocker"
    private val LAUNCHER_CHANNEL = "com.lastminute/launcher"
    private val PERMISSIONS_CHANNEL = "com.lastminute/permissions"
    private var isLauncherIntent = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Check if this was launched as a launcher (from home button)
        isLauncherIntent = intent?.action == Intent.ACTION_MAIN && 
                          intent?.hasCategory(Intent.CATEGORY_HOME) == true
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        
        // Update launcher intent flag when app receives new intent
        isLauncherIntent = intent.action == Intent.ACTION_MAIN && 
                          intent.hasCategory(Intent.CATEGORY_HOME)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // App blocker channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, APP_BLOCKER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "bringToForeground" -> {
                    bringAppToForeground()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // Launcher channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LAUNCHER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isLauncherIntent" -> {
                    result.success(isLauncherIntent)
                }
                "isDefaultLauncher" -> {
                    result.success(isDefaultLauncher())
                }
                "setAsLauncher" -> {
                    // This triggers the launcher chooser when user presses home
                    result.success(true)
                }
                "openLauncherSettings" -> {
                    openLauncherSettings()
                    result.success(true)
                }
                "openLastMinuteApp" -> {
                    openLastMinuteApp()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // Permissions channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PERMISSIONS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestUsageAccess" -> {
                    if (hasUsageStatsPermission()) {
                        result.success(true)
                    } else {
                        requestUsageStatsPermission()
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun isDefaultLauncher(): Boolean {
        val intent = Intent(Intent.ACTION_MAIN)
        intent.addCategory(Intent.CATEGORY_HOME)
        val pm = packageManager
        val resolveInfo = pm.resolveActivity(intent, 0)
        val defaultPackage = resolveInfo?.activityInfo?.packageName
        return defaultPackage == packageName
    }

    private fun bringAppToForeground() {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or 
                   Intent.FLAG_ACTIVITY_CLEAR_TOP or
                   Intent.FLAG_ACTIVITY_SINGLE_TOP or
                   Intent.FLAG_ACTIVITY_BROUGHT_TO_FRONT
        }
        startActivity(intent)
    }

    private fun openLauncherSettings() {
        val intent = Intent(Settings.ACTION_HOME_SETTINGS)
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        startActivity(intent)
    }

    private fun openLastMinuteApp() {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or 
                   Intent.FLAG_ACTIVITY_CLEAR_TOP or
                   Intent.FLAG_ACTIVITY_SINGLE_TOP
            action = Intent.ACTION_MAIN
            addCategory(Intent.CATEGORY_LAUNCHER)
        }
        startActivity(intent)
    }

    private fun hasUsageStatsPermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                android.os.Process.myUid(),
                packageName
            )
        } else {
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                android.os.Process.myUid(),
                packageName
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun requestUsageStatsPermission() {
        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        startActivity(intent)
    }
}
