package dev.kavach.kavach

import android.app.role.RoleManager
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "dev.kavach/calls"
    private var channel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        channel = ch
        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "hasRole" -> result.success(hasRole())
                "requestRole" -> { requestRole(); result.success(null) }
                "hasOverlay" -> result.success(CallAlert.canOverlay(this))
                "requestOverlay" -> { requestOverlay(); result.success(null) }
                "getAutoShield" -> result.success(Prefs.autoShield(this))
                "setAutoShield" -> {
                    Prefs.setAutoShield(this, call.arguments as? Boolean ?: false)
                    result.success(null)
                }
                // Drive the WHOLE unknown-call path without a real call, for demos/tests.
                "simulateUnknownCall" -> {
                    val num = call.argument<String>("number") ?: "+91 98765 43210"
                    CallAlert.show(applicationContext, num, false)
                    result.success(null)
                }
                // Speak a pre-recorded safety warning aloud + buzz, in the user's
                // language — for users who can't read the screen.
                "speakAlert" -> {
                    val level = call.argument<String>("level") ?: "HIGH"
                    val lang = call.argument<String>("lang") ?: "en"
                    SpokenAlert.play(applicationContext, level, lang)
                    result.success(null)
                }
                // Did we launch from a "Shield this call" tap?
                "consumePendingGuard" -> {
                    val p = Prefs.pendingGuard(this)
                    if (p) Prefs.setPendingGuard(this, false)
                    result.success(p)
                }
                else -> result.notImplemented()
            }
        }
        maybeStartGuard(intent)
    }

    private fun hasRole(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return false
        val rm = getSystemService(RoleManager::class.java) ?: return false
        return rm.isRoleAvailable(RoleManager.ROLE_CALL_SCREENING) &&
            rm.isRoleHeld(RoleManager.ROLE_CALL_SCREENING)
    }

    private fun requestRole() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return
        val rm = getSystemService(RoleManager::class.java) ?: return
        if (rm.isRoleAvailable(RoleManager.ROLE_CALL_SCREENING) &&
            !rm.isRoleHeld(RoleManager.ROLE_CALL_SCREENING)
        ) {
            startActivityForResult(
                rm.createRequestRoleIntent(RoleManager.ROLE_CALL_SCREENING), 1001
            )
        }
    }

    private fun requestOverlay() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
            startActivity(
                Intent(
                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    Uri.parse("package:$packageName")
                ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        maybeStartGuard(intent)
    }

    /** "Shield this call" was tapped → ask Flutter to start the guard. Sets a
     *  durable flag (consumed on startup) AND fires the channel for the warm
     *  case where Dart's handler is already attached. */
    private fun maybeStartGuard(intent: Intent?) {
        if (intent?.getBooleanExtra("start_guard", false) == true) {
            intent.removeExtra("start_guard")
            Prefs.setPendingGuard(this, true)
            Handler(Looper.getMainLooper()).postDelayed({
                channel?.invokeMethod("startGuard", null)
            }, 800)
        }
    }
}
