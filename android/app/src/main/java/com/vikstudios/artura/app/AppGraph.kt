package com.vikstudios.artura.app

import android.app.Application
import android.content.Context
import androidx.compose.runtime.staticCompositionLocalOf
import coil.ImageLoader
import coil.ImageLoaderFactory
import com.vikstudios.artura.core.AppLanguage
import com.vikstudios.artura.core.Appearance
import com.vikstudios.artura.core.Haptics
import com.vikstudios.artura.data.CatalogCache
import com.vikstudios.artura.data.CatalogImageInterceptor
import com.vikstudios.artura.data.ContentStore
import com.vikstudios.artura.data.UserStore
import com.vikstudios.artura.services.Analytics
import com.vikstudios.artura.services.ProStore
import com.vikstudios.artura.services.SupabaseAuth

/** The app's shared objects, created once (the equivalent of the iOS environment objects). */
object AppGraph {
    lateinit var content: ContentStore
        private set
    lateinit var user: UserStore
        private set
    lateinit var pro: ProStore
        private set
    private var ready = false

    fun init(context: Context) {
        if (ready) return
        val app = context.applicationContext
        AppLanguage.init(app)
        Appearance.init(app)
        Haptics.init(app)
        CatalogCache.init(app)
        SupabaseAuth.init(app)
        Analytics.init(app)
        content = ContentStore(app)
        user = UserStore(app)
        pro = ProStore(app)
        AppLanguage.addListener { from, to ->
            Analytics.track("language_changed", mapOf("from" to from, "to" to to))
            content.languageChanged()
        }
        ready = true
    }
}

class ArturaApplication : Application(), ImageLoaderFactory {
    override fun onCreate() {
        super.onCreate()
        AppGraph.init(this)
    }

    /** The app-wide image loader (default caches), with the catalog's single-download and retry rules. */
    override fun newImageLoader(): ImageLoader =
        ImageLoader.Builder(this).components { add(CatalogImageInterceptor()) }.build()
}

/** Access from any screen: `val user = LocalUser.current`. */
val LocalContent = staticCompositionLocalOf<ContentStore> { error("ContentStore not provided") }
val LocalUser = staticCompositionLocalOf<UserStore> { error("UserStore not provided") }
val LocalPro = staticCompositionLocalOf<ProStore> { error("ProStore not provided") }
