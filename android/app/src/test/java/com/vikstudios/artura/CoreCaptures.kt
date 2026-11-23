package com.vikstudios.artura

import com.vikstudios.artura.app.SplashView
import com.vikstudios.artura.main.ResultView
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

@RunWith(RobolectricTestRunner::class)
class CoreCaptures {
    @Test fun splash() = capture("core_splash") { SplashView() }
    @Test fun result() = capture("core_result") { ResultView(title = "Perfect score!", detail = "3 of 3 correct", onDone = {}) }
}
