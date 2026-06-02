package dev.kavach.kavach

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

/** The floating, Truecaller-style warning that pops over whatever's on screen
 *  when an UNKNOWN number calls. 100% on-device. Tapping "Shield this call"
 *  launches Kavach straight into the guard. Falls back to a notification if the
 *  overlay permission isn't granted (or the OEM blocks overlays). */
object CallAlert {
    private const val CHANNEL = "kavach_calls"
    private var view: View? = null

    fun canOverlay(ctx: Context): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(ctx)

    private fun dp(ctx: Context, v: Int) = (v * ctx.resources.displayMetrics.density).toInt()

    fun show(ctx: Context, number: String, verified: Boolean) {
        if (!canOverlay(ctx)) {
            notify(ctx, number, verified)
            return
        }
        Handler(Looper.getMainLooper()).post {
            remove(ctx)
            val wm = ctx.getSystemService(Context.WINDOW_SERVICE) as WindowManager
            val p = dp(ctx, 16)

            val card = LinearLayout(ctx).apply {
                orientation = LinearLayout.VERTICAL
                setPadding(p, p, p, p)
                background = GradientDrawable().apply {
                    cornerRadius = dp(ctx, 22).toFloat()
                    setColor(Color.parseColor("#1E1B2E"))
                    setStroke(dp(ctx, 2), Color.parseColor("#E63946"))
                }
            }
            card.addView(TextView(ctx).apply {
                text = "⚠  Unknown caller"
                setTextColor(Color.WHITE); textSize = 18f
                typeface = Typeface.DEFAULT_BOLD
            })
            card.addView(TextView(ctx).apply {
                text = number + "\nNot in your contacts" +
                    if (!verified) "  ·  network-unverified" else ""
                setTextColor(Color.parseColor("#C9C6D6")); textSize = 14f
                setPadding(0, dp(ctx, 6), 0, dp(ctx, 12))
            })
            val row = LinearLayout(ctx).apply { orientation = LinearLayout.HORIZONTAL }
            row.addView(Button(ctx).apply {
                text = "Shield this call"
                setOnClickListener { remove(ctx); launchGuard(ctx) }
            })
            row.addView(Button(ctx).apply {
                text = "Ignore"
                setOnClickListener { remove(ctx) }
            })
            card.addView(row)

            val type =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                    WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                else @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_PHONE
            val lp = WindowManager.LayoutParams(
                dp(ctx, 320),
                WindowManager.LayoutParams.WRAP_CONTENT,
                type,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
                PixelFormat.TRANSLUCENT
            ).apply { gravity = Gravity.TOP; y = dp(ctx, 56) }

            try {
                wm.addView(card, lp)
                view = card
                Handler(Looper.getMainLooper()).postDelayed({ remove(ctx) }, 22000)
            } catch (e: Exception) {
                notify(ctx, number, verified)
            }
        }
    }

    fun remove(ctx: Context) {
        view?.let {
            try {
                (ctx.getSystemService(Context.WINDOW_SERVICE) as WindowManager).removeView(it)
            } catch (_: Exception) {}
        }
        view = null
    }

    private fun launchGuard(ctx: Context) {
        val i = Intent(ctx, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            putExtra("start_guard", true)
        }
        ctx.startActivity(i)
    }

    /** Notification fallback (also the reliable path on overlay-restricted ROMs). */
    private fun notify(ctx: Context, number: String, verified: Boolean) {
        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL, "Unknown call alerts", NotificationManager.IMPORTANCE_HIGH)
            )
        }
        val tap = PendingIntent.getActivity(
            ctx, 0,
            Intent(ctx, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                putExtra("start_guard", true)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val n = android.app.Notification.Builder(ctx, CHANNEL)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle("⚠ Unknown caller")
            .setContentText("$number · tap to shield this call")
            .setAutoCancel(true)
            .setContentIntent(tap)
            .build()
        nm.notify(7711, n)
    }
}
