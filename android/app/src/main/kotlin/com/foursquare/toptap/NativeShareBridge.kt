package com.fourtech.toptap

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import java.io.File

/// Real, distinct native share targets that a generic URL-scheme launch
/// can't reach: explicit WhatsApp Business package targeting (the
/// `whatsapp://` scheme resolves to whichever WhatsApp variant the OS
/// picks, not necessarily Business), and Instagram's actual Story intent
/// (a different action than the plain ACTION_SEND used for the existing
/// "Instagram" share button, and one that needs real image data, not just
/// a link/text).
object NativeShareBridge {
    fun shareToWhatsAppBusiness(context: Context, text: String): Boolean {
        return try {
            val intent = Intent(Intent.ACTION_SEND)
            intent.type = "text/plain"
            intent.setPackage("com.whatsapp.w4b")
            intent.putExtra(Intent.EXTRA_TEXT, text)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
            true
        } catch (e: ActivityNotFoundException) {
            false
        }
    }

    fun shareToInstagramStory(context: Context, imagePath: String): Boolean {
        return try {
            val file = File(imagePath)
            val uri: Uri = FileProvider.getUriForFile(
                context, "${context.packageName}.fileprovider", file
            )
            val intent = Intent("com.instagram.share.ADD_TO_STORY")
            intent.setDataAndType(uri, "image/*")
            intent.putExtra("source_application", context.packageName)
            intent.setPackage("com.instagram.android")
            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
            true
        } catch (e: Exception) {
            false
        }
    }
}
