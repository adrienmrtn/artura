package com.vikstudios.artura.widget

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.os.Build
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.TouchApp
import androidx.compose.material.icons.rounded.Widgets
import androidx.compose.material.icons.rounded.Search
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vikstudios.artura.core.AType
import com.vikstudios.artura.core.ArtImage
import com.vikstudios.artura.core.L
import com.vikstudios.artura.core.Palette
import com.vikstudios.artura.core.PillButton
import com.vikstudios.artura.core.PillStyle
import com.vikstudios.artura.core.figtree
import com.vikstudios.artura.core.hexColor
import com.vikstudios.artura.onboarding.Mascot

enum class DailyWidgetStyle { Small, Medium, Large }

/** Shows the "Artwork of the day" widget in its three sizes, and how to add it to the home screen. */
@Composable
fun WidgetGuideView(onDone: () -> Unit) {
    val context = LocalContext.current
    val artwork = remember { DailyCatalog.artwork(context) }
    val manager = remember { AppWidgetManager.getInstance(context) }
    val canPin = Build.VERSION.SDK_INT >= 26 && manager.isRequestPinAppWidgetSupported

    val steps: List<Pair<ImageVector, String>> = listOf(
        Icons.Rounded.TouchApp to L("Touch and hold an empty area of your Home Screen."),
        Icons.Rounded.Widgets to L("Tap Widgets."),
        Icons.Rounded.Search to L("Search for Artura and pick a size."),
        Icons.Rounded.CheckCircle to L("Drag it to your Home Screen. A new artwork appears every day."),
    )

    Column(
        Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(horizontal = 24.dp).padding(bottom = 24.dp).navigationBarsPadding(),
        verticalArrangement = Arrangement.spacedBy(18.dp),
    ) {
        Column(Modifier.padding(top = 12.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(L("Artwork of the day widget"), style = AType.titleSmall, color = Palette.ink)
            Text(L("One masterpiece on your Home Screen, every morning."), style = AType.body, color = Palette.muted)
        }

        Row(verticalAlignment = Alignment.Top, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
            WidgetPreview(artwork, DailyWidgetStyle.Small, Modifier.size(150.dp))
            Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Mascot(92.dp)
                Text(L("I'll hang a new painting here every day."), style = figtree(14, FontWeight.SemiBold), color = Palette.ink, textAlign = TextAlign.Center)
            }
        }
        WidgetPreview(artwork, DailyWidgetStyle.Medium, Modifier.fillMaxWidth().height(150.dp))
        WidgetPreview(artwork, DailyWidgetStyle.Large, Modifier.fillMaxWidth().height(330.dp))

        Text(L("How to add it"), style = AType.heading, color = Palette.ink, modifier = Modifier.padding(top = 4.dp))
        Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(Palette.card).padding(horizontal = 16.dp)) {
            steps.forEachIndexed { i, (icon, text) ->
                Row(Modifier.padding(vertical = 12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Box(Modifier.size(32.dp).clip(CircleShape).background(Palette.mist), contentAlignment = Alignment.Center) {
                        Icon(icon, null, tint = Palette.blue, modifier = Modifier.size(17.dp))
                    }
                    Text(text, style = AType.small, color = Palette.ink, modifier = Modifier.weight(1f))
                }
                if (i < steps.size - 1) HorizontalDivider(color = Palette.line)
            }
        }

        Column(Modifier.padding(top = 4.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            // Android can place the widget directly, when the launcher allows it.
            if (canPin) {
                PillButton(L("Add the widget")) {
                    manager.requestPinAppWidget(ComponentName(context, DailyArtworkWidgetReceiver::class.java), null, null)
                }
                PillButton(L("Got it"), style = PillStyle.Secondary, onClick = onDone)
            } else {
                PillButton(L("Got it"), onClick = onDone)
            }
        }
    }
}

/** In-app picture of the widget, same look as the home screen one (DailyArtworkWidgetView.swift). */
@Composable
fun WidgetPreview(artwork: DailyArtwork?, style: DailyWidgetStyle, modifier: Modifier = Modifier) {
    val shape = RoundedCornerShape(24.dp)
    // The home screen widget stays light in dark mode: the preview keeps the light-mode colors.
    val ink = hexColor(0x2D2C2B)
    val muted = hexColor(0x5C5753)
    val line = hexColor(0xEFE8E3)
    val blue = hexColor(0x0061EF)
    Box(modifier.shadow(12.dp, shape, ambientColor = Color.Black.copy(alpha = 0.10f), spotColor = Color.Black.copy(alpha = 0.10f))
        .clip(shape).background(Color.White).border(1.dp, line, shape)) {
        if (artwork == null) {
            Text(L("Open Artura to see today's artwork"), style = figtree(13, FontWeight.SemiBold), color = ink,
                textAlign = TextAlign.Center, modifier = Modifier.align(Alignment.Center).padding(14.dp))
            return@Box
        }
        val label: @Composable () -> Unit = {
            Text(L("ARTWORK OF THE DAY"), style = figtree(10, FontWeight.Bold).copy(letterSpacing = 0.8.sp), color = blue, maxLines = 1)
        }
        when (style) {
            DailyWidgetStyle.Small -> {
                ArtImage(artwork.image, Modifier.fillMaxSize())
                Box(Modifier.fillMaxSize().background(Brush.verticalGradient(0.5f to Color.Transparent, 1f to Color.Black.copy(alpha = 0.72f))))
                Column(Modifier.align(Alignment.BottomStart).padding(14.dp), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text(artwork.title, style = figtree(16, FontWeight.Bold), color = Color.White, maxLines = 2, overflow = TextOverflow.Ellipsis)
                    Text(artwork.artist, style = figtree(12), color = Color.White.copy(alpha = 0.85f), maxLines = 1)
                }
            }
            DailyWidgetStyle.Medium -> BoxWithConstraints(Modifier.fillMaxSize()) {
                val side: Dp = maxHeight
                Row(Modifier.fillMaxSize()) {
                    ArtImage(artwork.image, Modifier.width(side).fillMaxHeight())
                    Column(Modifier.weight(1f).fillMaxHeight().padding(14.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        label()
                        Text(artwork.title, style = figtree(18, FontWeight.Bold), color = ink, maxLines = 2, overflow = TextOverflow.Ellipsis)
                        Text("${artwork.artist} · ${artwork.yearLabel}", style = figtree(12), color = muted, maxLines = 1, overflow = TextOverflow.Ellipsis)
                        Spacer(Modifier.weight(1f))
                        Text(artwork.teaser, style = figtree(12), color = muted, maxLines = 3, overflow = TextOverflow.Ellipsis)
                    }
                }
            }
            DailyWidgetStyle.Large -> Column(Modifier.fillMaxSize()) {
                ArtImage(artwork.image, Modifier.fillMaxWidth().weight(1f))
                Column(Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    label()
                    Text(artwork.title, style = figtree(21, FontWeight.Bold), color = ink, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    Text("${artwork.artist} · ${artwork.yearLabel}", style = figtree(13), color = muted, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    Text(artwork.teaser, style = figtree(13), color = muted, maxLines = 2, overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.padding(top = 2.dp))
                }
            }
        }
    }
}
