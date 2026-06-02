package dev.kavach.kavach

import android.content.Context
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.ContactsContract
import androidx.core.content.ContextCompat

/** On-device check: is this number someone the user already knows? Used only to
 *  SKIP known callers — the number and contacts never leave the phone. */
object Contacts {
    fun isKnown(ctx: Context, number: String): Boolean {
        if (number.isBlank()) return false
        // No contacts permission → treat everyone as "unknown" (fail safe: we'd
        // rather warn than miss, and we never expose the data anyway).
        if (ContextCompat.checkSelfPermission(ctx, android.Manifest.permission.READ_CONTACTS)
            != PackageManager.PERMISSION_GRANTED) return false
        return try {
            val uri = Uri.withAppendedPath(
                ContactsContract.PhoneLookup.CONTENT_FILTER_URI, Uri.encode(number)
            )
            ctx.contentResolver.query(
                uri, arrayOf(ContactsContract.PhoneLookup._ID), null, null, null
            )?.use { it.moveToFirst() } ?: false
        } catch (e: Exception) {
            false
        }
    }
}
