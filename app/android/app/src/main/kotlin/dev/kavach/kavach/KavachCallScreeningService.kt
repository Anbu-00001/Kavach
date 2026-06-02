package dev.kavach.kavach

import android.os.Build
import android.telecom.Call
import android.telecom.CallScreeningService
import android.telecom.Connection

/** Hooked by the system for every incoming/outgoing call once the user grants
 *  the call-screening role. We NEVER block a call — advisory only: we let it
 *  through, and if it's an UNKNOWN incoming number (and auto-shield is on) we
 *  float the warning. */
class KavachCallScreeningService : CallScreeningService() {
    override fun onScreenCall(callDetails: Call.Details) {
        // Always allow the call through — Kavach advises, it does not block.
        try {
            respondToCall(callDetails, CallResponse.Builder().build())
        } catch (_: Exception) {}

        // callDirection is API 29+. Below that, we can't tell in/out → skip.
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return
        if (callDetails.callDirection != Call.Details.DIRECTION_INCOMING) return

        if (!Prefs.autoShield(this)) return

        val number = callDetails.handle?.schemeSpecificPart ?: return
        if (Contacts.isKnown(this, number)) return // known caller → don't nag

        // STIR/SHAKEN network verification (API 30+): "passed" means the carrier
        // confirmed the number isn't spoofed.
        val verified = Build.VERSION.SDK_INT >= Build.VERSION_CODES.R &&
            callDetails.callerNumberVerificationStatus == Connection.VERIFICATION_STATUS_PASSED

        CallAlert.show(applicationContext, number, verified)
    }
}
