package com.vikstudios.artura.learn

import android.app.Activity
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.Lock
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.vikstudios.artura.app.LocalPro
import com.vikstudios.artura.core.AType
import com.vikstudios.artura.core.ArcHeaderShape
import com.vikstudios.artura.core.ArtImage
import com.vikstudios.artura.core.Haptics
import com.vikstudios.artura.core.L
import com.vikstudios.artura.core.Palette
import com.vikstudios.artura.core.PillButton
import com.vikstudios.artura.core.TextLinkButton
import com.vikstudios.artura.core.appearUp
import com.vikstudios.artura.core.figtree
import com.vikstudios.artura.core.pressable
import com.vikstudios.artura.data.Artwork
import com.vikstudios.artura.services.Analytics
import com.vikstudios.artura.services.TrialOffer
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * Paywall shown inside a lesson, built around the painting being read (port of LessonPaywall.swift).
 * Used when a free reader reaches the quiz, or goes on with a second lesson in the same day.
 * `closeTitle`: label of the way out; `closeDelay`: seconds before it appears; `onUnlocked`: once subscribed.
 */
@Composable
fun LessonPaywall(
    artwork: Artwork, title: String, subtitle: String, closeTitle: String, closeDelay: Int = 0,
    onClose: () -> Unit, onUnlocked: () -> Unit,
) {
    val pro = LocalPro.current
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var canClose by remember { mutableStateOf(false) }
    val closeAlpha by animateFloatAsState(if (canClose) 1f else 0f, tween(600), label = "close")
    val benefits = listOf(
        L("Every lesson, as many as you like each day"),
        L("The quiz at the end of each lesson"),
        L("All games, no daily limit"),
    )
    val yearly = pro.yearly
    val trial = TrialOffer.of(yearly)
    val priceLine = when {
        yearly == null -> null
        trial != null -> L("%@ days free, then %@ per year", "${trial.trialDays}", trial.yearlyPrice)
        else -> L("%@ per year", yearly.displayPrice)
    }

    LaunchedEffect(Unit) {
        Analytics.track("paywall_viewed", mapOf("kind" to "lesson", "title" to title, "artwork" to artwork.id))
        launch { if (pro.products.isEmpty()) pro.loadProducts() }
        if (closeDelay > 0) delay(closeDelay * 1000L)
        canClose = true
    }

    fun purchase() {
        val product = pro.yearly ?: return
        val activity = context as? Activity ?: return
        scope.launch {
            if (pro.purchase(activity, product)) { Haptics.success(); onUnlocked() }
        }
    }

    Column(Modifier.fillMaxSize().background(Palette.bg).navigationBarsPadding(), horizontalAlignment = Alignment.CenterHorizontally) {
        // The painting of the lesson, under the arc
        Box(Modifier.fillMaxWidth().height(300.dp), contentAlignment = Alignment.BottomCenter) {
            ArtImage(artwork.image, Modifier.fillMaxSize().clip(ArcHeaderShape), anchor = artwork.focusPoint)
            Box(
                Modifier.offset(y = (-12).dp).size(56.dp).clip(CircleShape).background(Palette.blue).border(4.dp, Color.White, CircleShape),
                contentAlignment = Alignment.Center,
            ) { Icon(Icons.Rounded.Lock, null, tint = Color.White, modifier = Modifier.size(22.dp)) }
        }

        Column(
            Modifier.padding(horizontal = 24.dp).offset(y = (-24).dp).appearUp(0.05),
            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Text(title, style = figtree(28, FontWeight.Bold), color = Palette.ink, textAlign = TextAlign.Center)
            Text(subtitle, style = AType.body, color = Palette.muted, textAlign = TextAlign.Center)
        }

        Column(
            Modifier.padding(horizontal = 24.dp).fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(Palette.card).padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            benefits.forEachIndexed { i, benefit ->
                Row(Modifier.appearUp(0.1 + 0.06 * i), horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Rounded.Check, null, tint = Palette.green, modifier = Modifier.size(18.dp))
                    Text(benefit, style = figtree(15), color = Palette.ink)
                }
            }
        }

        Spacer(Modifier.weight(1f).heightIn(min = 12.dp))

        Column(Modifier.padding(horizontal = 24.dp).padding(bottom = 4.dp), horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(2.dp)) {
            pro.lastError?.let {
                Text(it, style = AType.caption, color = Palette.red, textAlign = TextAlign.Center, modifier = Modifier.padding(bottom = 4.dp))
            }
            PillButton(Modifier.graphicsLayer { alpha = if (yearly == null) 0.4f else 1f },
                enabled = yearly != null && !pro.isPurchasing, onClick = { purchase() }) {
                if (pro.isPurchasing) CircularProgressIndicator(color = Color.White, strokeWidth = 2.dp, modifier = Modifier.size(22.dp))
                else Text(if (trial == null) L("Unlock Artura Pro") else L("Start free trial"), style = AType.bodyStrong, color = Color.White)
            }
            Text(priceLine ?: L("Price unavailable"), style = figtree(14), color = Palette.muted, modifier = Modifier.padding(top = 8.dp))
            TextLinkButton(closeTitle, Modifier.graphicsLayer { alpha = closeAlpha }) {
                if (canClose) {
                    Analytics.track("paywall_closed", mapOf("kind" to "lesson", "title" to title, "artwork" to artwork.id))
                    onClose()
                }
            }
            Box(Modifier.heightIn(min = 36.dp).pressable {
                scope.launch {
                    pro.restore()
                    if (pro.isPro) { Haptics.success(); onUnlocked() }
                }
            }, contentAlignment = Alignment.Center) {
                Text(L("Restore purchases"), style = figtree(12), color = Palette.muted)
            }
        }
    }
}
