package com.vikstudios.artura.app

import android.content.Context
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.LocalTextStyle
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.ProcessLifecycleOwner
import com.vikstudios.artura.R
import com.vikstudios.artura.core.AType
import com.vikstudios.artura.core.AppLanguage
import com.vikstudios.artura.core.Haptics
import com.vikstudios.artura.core.L
import com.vikstudios.artura.core.Palette
import com.vikstudios.artura.core.figtree
import com.vikstudios.artura.main.MainTabView
import com.vikstudios.artura.onboarding.OnboardingDebug
import com.vikstudios.artura.onboarding.OnboardingFlow
import com.vikstudios.artura.services.Analytics
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {
    override fun attachBaseContext(newBase: Context) {
        AppGraph.init(newBase)
        super.attachBaseContext(AppLanguage.wrap(newBase))
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        // Bar icons follow the system appearance (dark icons in light mode, light icons in dark mode).
        enableEdgeToEdge(
            statusBarStyle = SystemBarStyle.auto(android.graphics.Color.TRANSPARENT, android.graphics.Color.TRANSPARENT),
            navigationBarStyle = SystemBarStyle.auto(android.graphics.Color.WHITE, 0xFF141312.toInt()),
        )
        super.onCreate(savedInstanceState)
        if (savedInstanceState == null) {
            AppDebug.read(intent)
            Analytics.disabled = AppDebug.hasArguments
            AppGraph.user.applyDebug { OnboardingDebug.prepare(AppDebug.prepare(it)) }
        }
        val graph = AppGraph
        ProcessLifecycleOwner.get().lifecycle.addObserver(LifecycleEventObserver { _, event ->
            // Whatever is waiting leaves before the app is suspended; progress saved from another phone comes back.
            if (event == Lifecycle.Event.ON_STOP) Analytics.flush()
            if (event == Lifecycle.Event.ON_START) {
                Analytics.flush()
                kotlinx.coroutines.MainScope().launch { graph.user.refreshFromAccount() }
            }
        })
        setContent {
            val language = AppLanguage.code
            // Dark mode follows the system appearance.
            val dark = isSystemInDarkTheme()
            if (Palette.isDark != dark) Palette.isDark = dark
            CompositionLocalProvider(
                LocalContent provides graph.content,
                LocalUser provides graph.user,
                LocalPro provides graph.pro,
                LocalLayoutDirection provides if (AppLanguage.isRightToLeft) LayoutDirection.Rtl else LayoutDirection.Ltr,
            ) {
                MaterialTheme(
                    colorScheme = if (Palette.isDark) darkColorScheme(primary = Palette.blue, background = Palette.bg, surface = Palette.bg)
                    else lightColorScheme(primary = Palette.blue, background = Palette.bg, surface = Palette.bg),
                ) {
                    CompositionLocalProvider(LocalTextStyle provides AType.body.copy(color = Palette.ink)) {
                        key(language) { RootView() }
                    }
                }
            }
        }
    }
}

/** True once the launch screen has played in this process. */
private var splashPlayed = false

@Composable
fun RootView() {
    val user = LocalUser.current
    val host = remember { CoverHost() }
    // Played once per launch: changing the language rebuilds the screens, not the splash.
    var splash by remember { mutableStateOf(!splashPlayed && !OnboardingDebug.flag("noSplash")) }

    LaunchedEffect(Unit) {
        if (splashPlayed) return@LaunchedEffect
        splashPlayed = true
        Analytics.track("app_opened", mapOf(
            "onboarded" to user.profile.onboarded,
            "streak" to user.streak,
            "lessons_completed" to user.profile.completedLessons.size,
        ))
        // Wait for the logo animation to play, then the app fades in.
        if (OnboardingDebug.flag("holdSplash")) return@LaunchedEffect
        delay(2400)
        splash = false
    }

    CompositionLocalProvider(LocalCoverHost provides host) {
        Box(Modifier.fillMaxSize().background(Palette.bg), contentAlignment = Alignment.TopCenter) {
            // On tablets, the interface keeps a phone width, centered.
            Box(Modifier.widthIn(max = 520.dp).fillMaxSize()) {
                AnimatedContent(
                    targetState = user.profile.onboarded,
                    transitionSpec = { fadeIn(tween(240)) togetherWith fadeOut(tween(240)) },
                    label = "root",
                ) { onboarded ->
                    if (onboarded) MainTabView() else OnboardingFlow()
                }
                CoverLayer(host)
            }
            AnimatedVisibility(splash, enter = fadeIn(), exit = fadeOut(tween(450, easing = FastOutSlowInEasing))) {
                SplashView()
            }
        }
    }
}

// MARK: - Animated launch screen

@Composable
fun SplashView() {
    val name = "Artura"
    val logo = remember { Animatable(0f) }
    val halo = remember { Animatable(0f) }
    val motto = remember { Animatable(0f) }
    var letters by remember { mutableIntStateOf(0) }
    val scope = rememberCoroutineScope()

    LaunchedEffect(Unit) {
        scope.launch { logo.animateTo(1f, tween(550)) }
        scope.launch { delay(500); halo.animateTo(1f, tween(900)) }
        scope.launch { delay(450); Haptics.soft() }
        scope.launch {
            delay(550)
            for (i in 1..name.length) { delay(70); letters = i }
        }
        scope.launch { delay(1250); motto.animateTo(1f, tween(500)) }
    }

    Box(
        Modifier.fillMaxSize().background(Palette.bg).semantics { contentDescription = L("Artura. Your daily dose of art, in your pocket.") },
        contentAlignment = Alignment.Center,
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(22.dp), modifier = Modifier.padding(horizontal = 32.dp)) {
            Box(contentAlignment = Alignment.Center) {
                // Halo that expands once behind the logo.
                Box(
                    Modifier.size(128.dp)
                        .graphicsLayer {
                            val s = 1f + 0.45f * halo.value
                            scaleX = s; scaleY = s
                            alpha = if (halo.value > 0f) 1f - halo.value else logo.value
                        }
                        .border(3.dp, Palette.yellow.copy(alpha = 0.7f), RoundedCornerShape(34.dp))
                )
                Image(
                    painterResource(R.drawable.logo), null, contentScale = ContentScale.Crop,
                    modifier = Modifier.size(128.dp)
                        .graphicsLayer {
                            val s = 0.72f + 0.28f * logo.value
                            scaleX = s; scaleY = s; alpha = logo.value
                        }
                        .shadow(18.dp, RoundedCornerShape(30.dp))
                        .clip(RoundedCornerShape(30.dp))
                )
            }
            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Row {
                    name.forEachIndexed { i, c ->
                        val shown = i < letters
                        val a by androidx.compose.animation.core.animateFloatAsState(if (shown) 1f else 0f, tween(300), label = "l$i")
                        Text(c.toString(), style = figtree(46, FontWeight.Bold), color = Palette.ink,
                            modifier = Modifier.graphicsLayer { alpha = a; translationY = (1 - a) * 12.dp.toPx() })
                    }
                }
                Text(L("Your daily dose of art, in your pocket"), style = figtree(16, FontWeight.Medium), color = Palette.muted,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.graphicsLayer { alpha = motto.value; translationY = (1 - motto.value) * 8.dp.toPx() })
            }
        }
    }
}
