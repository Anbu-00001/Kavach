package dev.kavach.kavach

import android.content.Context

/** Tiny native pref the call-screening service reads (the Flutter UI flips it
 *  via the method channel). Kept separate from Flutter's prefs so the service
 *  has no Flutter dependency. */
object Prefs {
    private const val FILE = "kavach_native"
    private const val KEY_AUTO_SHIELD = "auto_shield"
    private const val KEY_PENDING_GUARD = "pending_guard"

    private fun sp(ctx: Context) = ctx.getSharedPreferences(FILE, Context.MODE_PRIVATE)

    fun autoShield(ctx: Context): Boolean = sp(ctx).getBoolean(KEY_AUTO_SHIELD, false)
    fun setAutoShield(ctx: Context, on: Boolean) =
        sp(ctx).edit().putBoolean(KEY_AUTO_SHIELD, on).apply()

    fun pendingGuard(ctx: Context): Boolean = sp(ctx).getBoolean(KEY_PENDING_GUARD, false)
    fun setPendingGuard(ctx: Context, on: Boolean) =
        sp(ctx).edit().putBoolean(KEY_PENDING_GUARD, on).apply()
}
