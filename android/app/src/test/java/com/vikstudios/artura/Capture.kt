package com.vikstudios.artura

import androidx.compose.material3.LocalTextStyle
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.unit.LayoutDirection
import androidx.test.core.app.ApplicationProvider
import com.github.takahirom.roborazzi.captureRoboImage
import com.vikstudios.artura.app.AppGraph
import com.vikstudios.artura.app.CoverHost
import com.vikstudios.artura.app.CoverLayer
import com.vikstudios.artura.app.LocalContent
import com.vikstudios.artura.app.LocalCoverHost
import com.vikstudios.artura.app.LocalPro
import com.vikstudios.artura.app.LocalUser
import com.vikstudios.artura.core.AType
import com.vikstudios.artura.core.AppLanguage
import com.vikstudios.artura.core.Palette
import com.vikstudios.artura.services.Analytics

/**
 * Renders a screen on the JVM and saves it to android/captures/<name>.png (phone size, 393×852 dp).
 * Run: `gradle :app:testDebugUnitTest --tests '*Captures*'` (images written by Roborazzi in record mode).
 */
fun capture(name: String, language: String = "en", content: @Composable () -> Unit) {
    val context = ApplicationProvider.getApplicationContext<android.content.Context>()
    AppGraph.init(context)
    Analytics.disabled = true
    AppLanguage.set(language)
    captureRoboImage("../captures/$name.png") {
        val host = remember { CoverHost() }
        CompositionLocalProvider(
            LocalContent provides AppGraph.content,
            LocalUser provides AppGraph.user,
            LocalPro provides AppGraph.pro,
            LocalCoverHost provides host,
            LocalLayoutDirection provides if (AppLanguage.isRightToLeft) LayoutDirection.Rtl else LayoutDirection.Ltr,
        ) {
            MaterialTheme(colorScheme = lightColorScheme(primary = Palette.blue, background = Palette.bg, surface = Palette.bg)) {
                CompositionLocalProvider(LocalTextStyle provides AType.body.copy(color = Palette.ink)) {
                    content()
                    CoverLayer(host)
                }
            }
        }
    }
}
