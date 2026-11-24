package com.vikstudios.artura.widget

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.LocalSize
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.SizeMode
import androidx.glance.action.actionStartActivity
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.ContentScale
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxHeight
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.width
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import com.vikstudios.artura.R
import com.vikstudios.artura.app.MainActivity
import com.vikstudios.artura.core.hexColor

// The "Artwork of the day" home screen widget (port of ArturaWidget.swift and DailyArtworkWidgetView.swift).
// It reads the same content.json as the app and follows the same rule as the feed for the day's artwork.
// It is redrawn every hour (appwidget-provider updatePeriodMillis): the artwork changes with the day.

class DailyArtworkWidget : GlanceAppWidget() {
    companion object {
        private val SMALL = DpSize(110.dp, 110.dp)
        private val MEDIUM = DpSize(250.dp, 110.dp)
        private val LARGE = DpSize(250.dp, 250.dp)
    }

    override val sizeMode = SizeMode.Responsive(setOf(SMALL, MEDIUM, LARGE))

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val artwork = DailyCatalog.artwork(context)
        val picture = artwork?.let { loadPicture(context, it.image) }
        val texts = WidgetTexts(
            label = DailyCatalog.text(context, "ARTWORK OF THE DAY"),
            empty = DailyCatalog.text(context, "Open Artura to see today's artwork"),
        )
        provideContent { WidgetContent(artwork, picture, texts) }
    }
}

private data class WidgetTexts(val label: String, val empty: String)

// The home-screen widget keeps the light colors (Palette follows the app's appearance).
private val ink = ColorProvider(hexColor(0x2D2C2B))
private val muted = ColorProvider(hexColor(0x5C5753))
private val blue = ColorProvider(hexColor(0x0061EF))
private val white = ColorProvider(Color.White)

@Composable
private fun WidgetContent(artwork: DailyArtwork?, picture: Bitmap?, texts: WidgetTexts) {
    val size = LocalSize.current
    val style = when {
        size.width < 200.dp -> DailyWidgetStyle.Small
        size.height < 200.dp -> DailyWidgetStyle.Medium
        else -> DailyWidgetStyle.Large
    }
    val root = GlanceModifier.fillMaxSize().cornerRadius(24.dp).background(Color.White)
        .clickable(actionStartActivity<MainActivity>())

    if (artwork == null) {
        Box(root.padding(14.dp), contentAlignment = Alignment.Center) {
            Text(texts.empty, style = TextStyle(color = ink, fontSize = 13.sp, fontWeight = FontWeight.Medium))
        }
        return
    }

    @Composable
    fun painting(modifier: GlanceModifier) {
        if (picture != null) Image(ImageProvider(picture), artwork.title, modifier, contentScale = ContentScale.Crop)
        else Box(modifier.background(hexColor(0xDCEBFF))) {}
    }

    @Composable
    fun label() = Text(texts.label, maxLines = 1, style = TextStyle(color = blue, fontSize = 10.sp, fontWeight = FontWeight.Bold))

    when (style) {
        DailyWidgetStyle.Small -> Box(root) {
            painting(GlanceModifier.fillMaxSize())
            // Dark gradient at the bottom, under the title.
            Image(ImageProvider(R.drawable.widget_scrim), null, GlanceModifier.fillMaxSize(), contentScale = ContentScale.FillBounds)
            Column(GlanceModifier.fillMaxSize().padding(14.dp), verticalAlignment = Alignment.Bottom) {
                Text(artwork.title, maxLines = 2, style = TextStyle(color = white, fontSize = 16.sp, fontWeight = FontWeight.Bold))
                Text(artwork.artist, maxLines = 1, style = TextStyle(color = ColorProvider(Color.White.copy(alpha = 0.85f)), fontSize = 12.sp))
            }
        }
        DailyWidgetStyle.Medium -> Row(root) {
            painting(GlanceModifier.width(size.height).fillMaxHeight())
            Column(GlanceModifier.defaultWeight().fillMaxHeight().padding(14.dp)) {
                label()
                Spacer(GlanceModifier.height(4.dp))
                Text(artwork.title, maxLines = 2, style = TextStyle(color = ink, fontSize = 18.sp, fontWeight = FontWeight.Bold))
                Spacer(GlanceModifier.height(4.dp))
                Text("${artwork.artist} · ${artwork.yearLabel}", maxLines = 1, style = TextStyle(color = muted, fontSize = 12.sp))
                Spacer(GlanceModifier.defaultWeight())
                Text(artwork.teaser, maxLines = 3, style = TextStyle(color = muted, fontSize = 12.sp))
            }
        }
        DailyWidgetStyle.Large -> Column(root) {
            painting(GlanceModifier.fillMaxWidth().defaultWeight())
            Column(GlanceModifier.fillMaxWidth().padding(16.dp)) {
                label()
                Spacer(GlanceModifier.height(4.dp))
                Text(artwork.title, maxLines = 1, style = TextStyle(color = ink, fontSize = 21.sp, fontWeight = FontWeight.Bold))
                Spacer(GlanceModifier.height(4.dp))
                Text("${artwork.artist} · ${artwork.yearLabel}", maxLines = 1, style = TextStyle(color = muted, fontSize = 13.sp))
                Spacer(GlanceModifier.height(6.dp))
                Text(artwork.teaser, maxLines = 2, style = TextStyle(color = muted, fontSize = 13.sp))
            }
        }
    }
}

/** The bundled picture, reduced to about 720 px (widgets travel as RemoteViews, with a size limit). */
@SuppressLint("DiscouragedApi")
private fun loadPicture(context: Context, name: String): Bitmap? {
    val id = context.resources.getIdentifier(name, "drawable", context.packageName)
    if (id == 0) return null
    val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
    BitmapFactory.decodeResource(context.resources, id, bounds)
    var sample = 1
    while (maxOf(bounds.outWidth, bounds.outHeight) / (sample * 2) >= 720) sample *= 2
    val bitmap = BitmapFactory.decodeResource(context.resources, id, BitmapFactory.Options().apply { inSampleSize = sample }) ?: return null
    val longest = maxOf(bitmap.width, bitmap.height)
    if (longest <= 720) return bitmap
    val k = 720f / longest
    return Bitmap.createScaledBitmap(bitmap, (bitmap.width * k).toInt(), (bitmap.height * k).toInt(), true)
}

class DailyArtworkWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = DailyArtworkWidget()
}

