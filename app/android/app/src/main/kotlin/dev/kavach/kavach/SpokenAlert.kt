package dev.kavach.kavach

import android.content.Context
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.os.Build
import android.util.Log
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager

/**
 * Speaks a pre-recorded, pre-vetted safety warning in the user's own language and
 * buzzes the phone — the channels an illiterate, low-vision or hard-of-hearing
 * elder can actually receive (most of India's fraud victims can't read the screen).
 *
 * Fully offline: it only ever plays one of the bundled res/raw clips — no TTS
 * engine, no language pack, no network. Deterministic, like our on-screen text:
 * it never synthesises words at runtime, so it can't be made to say anything wrong.
 * Every path is wrapped so an alert can never crash the call shield.
 */
object SpokenAlert {
    private val LANGS = setOf("en", "hi", "ta", "te")
    private var player: MediaPlayer? = null

    fun play(ctx: Context, level: String, lang: String) {
        try {
            val l = if (lang in LANGS) lang else "en"
            val kind = if (level == "HIGH") "warn_high" else "warn_caution"
            val resId = ctx.resources.getIdentifier("${kind}_$l", "raw", ctx.packageName)
            Log.i("KAVACH_VOICE", "speak level=$level lang=$l resId=$resId")
            if (resId == 0) return
            buzz(ctx, level)
            stop()
            val afd = ctx.resources.openRawResourceFd(resId) ?: return
            val mp = MediaPlayer()
            player = mp
            mp.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ASSISTANCE_ACCESSIBILITY)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build()
            )
            mp.setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
            afd.close()
            mp.setOnPreparedListener { it.start() }
            mp.setOnCompletionListener {
                it.release()
                if (player === it) player = null
            }
            mp.setOnErrorListener { _, _, _ -> stop(); true }
            mp.prepareAsync()
        } catch (e: Exception) {
            // An advisory warning must never take the app down.
        }
    }

    private fun stop() {
        try {
            player?.release()
        } catch (_: Exception) {
        }
        player = null
    }

    private fun buzz(ctx: Context, level: String) {
        try {
            val vib: Vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                (ctx.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                ctx.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }
            // HIGH = three firm pulses; CAUTION = one gentle nudge.
            val pattern = if (level == "HIGH")
                longArrayOf(0, 400, 160, 400, 160, 400) else longArrayOf(0, 220)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vib.vibrate(VibrationEffect.createWaveform(pattern, -1))
            } else {
                @Suppress("DEPRECATION")
                vib.vibrate(pattern, -1)
            }
        } catch (_: Exception) {
        }
    }
}
