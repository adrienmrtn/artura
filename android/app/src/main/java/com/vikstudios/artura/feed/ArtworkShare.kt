package com.vikstudios.artura.feed

import android.annotation.SuppressLint
import android.content.ClipData
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.drawable.BitmapDrawable
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.core.content.FileProvider
import coil.imageLoader
import coil.request.ImageRequest
import coil.request.SuccessResult
import com.vikstudios.artura.core.Haptics
import com.vikstudios.artura.core.L
import com.vikstudios.artura.core.Palette
import com.vikstudios.artura.data.Artwork
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.MainScope
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File

/** Links used when sharing. The Play Store address is unknown until the app is published. */
object AppLinks {
    /** Play Store page of the app, added to shared messages once it exists. */
    val playStore: String? = null
    /** Address that receives suggestions. Empty: the "Suggest an idea" row is hidden. */
    const val supportEmail = "support@vikstudios.com"
}

/** Text that goes with a shared artwork. */
val Artwork.shareMessage: String
    get() {
        var text = L("“%@” by %@, %@. I'm learning its story on Artura.", title, artist, yearLabel)
        AppLinks.playStore?.let { text += " $it" }
        return text
    }

/**
 * Opens the system share sheet for an artwork: its image (bundled, or downloaded from the catalog),
 * with a short message. Falls back to the message alone if the picture can't be had.
 */
fun shareArtwork(context: Context, artwork: Artwork) {
    Haptics.tap()
    MainScope().launch {
        val file = withContext(Dispatchers.IO) { runCatching { pictureFile(context, artwork) }.getOrNull() }
        val send = Intent(Intent.ACTION_SEND).apply {
            putExtra(Intent.EXTRA_SUBJECT, artwork.title)
            putExtra(Intent.EXTRA_TEXT, artwork.shareMessage)
            if (file != null) {
                val uri = FileProvider.getUriForFile(context, "${context.packageName}.files", file)
                type = "image/jpeg"
                putExtra(Intent.EXTRA_STREAM, uri)
                clipData = ClipData.newRawUri(artwork.title, uri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            } else {
                type = "text/plain"
            }
        }
        val chooser = Intent.createChooser(send, L("Share %@", artwork.title))
        if (context !is android.app.Activity) chooser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        runCatching { context.startActivity(chooser) }
    }
}

/** The picture written to cache/shared/<id>.jpg, for the FileProvider. */
@SuppressLint("DiscouragedApi")
private suspend fun pictureFile(context: Context, artwork: Artwork): File? {
    val bitmap: Bitmap = if (artwork.isRemote) {
        val result = context.imageLoader.execute(ImageRequest.Builder(context).data(artwork.image).allowHardware(false).build())
        ((result as? SuccessResult)?.drawable as? BitmapDrawable)?.bitmap ?: return null
    } else {
        val id = context.resources.getIdentifier(artwork.image, "drawable", context.packageName)
        if (id == 0) return null
        BitmapFactory.decodeResource(context.resources, id) ?: return null
    }
    val dir = File(context.cacheDir, "shared").apply { mkdirs() }
    val file = File(dir, "${artwork.id}.jpg")
    file.outputStream().use { bitmap.compress(Bitmap.CompressFormat.JPEG, 90, it) }
    return file
}

/** Round white button used under a feed card (share, like, save). */
@Composable
fun RoundActionLabel(icon: ImageVector, modifier: Modifier = Modifier, tint: Color = Palette.ink, size: Dp = 52.dp, description: String? = null) {
    Box(modifier.size(size, size + 3.dp)) {
        Box(Modifier.size(size).offset(y = 3.dp).background(Palette.lip, CircleShape))
        Box(
            Modifier.size(size).background(Color.White, CircleShape).border(1.dp, Palette.line, CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            Icon(icon, description, tint = tint, modifier = Modifier.size(size * 0.42f))
        }
    }
}
