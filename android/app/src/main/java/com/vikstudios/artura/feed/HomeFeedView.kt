package com.vikstudios.artura.feed

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsTopHeight
import androidx.compose.foundation.pager.VerticalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowForward
import androidx.compose.material.icons.outlined.LibraryBooks
import androidx.compose.material.icons.outlined.WorkspacePremium
import androidx.compose.material.icons.rounded.Bookmark
import androidx.compose.material.icons.rounded.BookmarkBorder
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.Favorite
import androidx.compose.material.icons.rounded.FavoriteBorder
import androidx.compose.material.icons.rounded.FilterList
import androidx.compose.material.icons.rounded.History
import androidx.compose.material.icons.rounded.IosShare
import androidx.compose.material.icons.rounded.KeyboardArrowUp
import androidx.compose.material.icons.rounded.Search
import androidx.compose.material.icons.rounded.WorkspacePremium
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import coil.imageLoader
import coil.request.ImageRequest
import com.vikstudios.artura.app.AppDebug
import com.vikstudios.artura.app.FullScreenCover
import com.vikstudios.artura.app.LocalContent
import com.vikstudios.artura.app.LocalPro
import com.vikstudios.artura.app.LocalUser
import com.vikstudios.artura.core.AType
import com.vikstudios.artura.core.ArtImage
import com.vikstudios.artura.core.Haptics
import com.vikstudios.artura.core.L
import com.vikstudios.artura.core.Palette
import com.vikstudios.artura.core.PillButton
import com.vikstudios.artura.core.PillStyle
import com.vikstudios.artura.core.StreakChip
import com.vikstudios.artura.core.TagPill
import com.vikstudios.artura.core.ZoomTarget
import com.vikstudios.artura.core.ZoomViewer
import com.vikstudios.artura.core.figtree
import com.vikstudios.artura.core.pressable
import com.vikstudios.artura.data.Artwork
import com.vikstudios.artura.main.CourseFlow
import com.vikstudios.artura.onboarding.MascotBubble
import com.vikstudios.artura.onboarding.PaywallScreen
import com.vikstudios.artura.services.Analytics
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.launch
import kotlin.random.Random

/** Sheets that can open from the feed's top bar. */
sealed class FeedSheet {
    data object Filter : FeedSheet()
    data object Search : FeedSheet()
    data class Library(val tab: LibraryTab) : FeedSheet()

    companion object {
        /** Sheet to open at launch, from the `feedSheet` debug argument. */
        val debugInitial: FeedSheet?
            get() = when (AppDebug.string("feedSheet")) {
                "filter" -> Filter
                "search" -> Search
                "history" -> Library(LibraryTab.History)
                "library" -> Library(LibraryTab.Favorites)
                "saved" -> Library(LibraryTab.Saved)
                else -> null
            }
    }
}

/** Drawn once per launch: the feed order changes from one launch to the next. */
private val sessionSeed = Random.nextLong()

/**
 * Home: a vertical feed, one artwork per screen. Swipe up for the next one, open its lesson,
 * like it, save it or share it.
 */
@Composable
fun HomeFeedView(onExplore: () -> Unit, onReview: () -> Unit) {
    val user = LocalUser.current
    val content = LocalContent.current
    val pro = LocalPro.current
    val context = LocalContext.current

    var filter by remember { mutableStateOf(FeedFilter()) }
    var course by remember { mutableStateOf<Artwork?>(null) }
    var sheet by remember { mutableStateOf(FeedSheet.debugInitial) }
    var showPaywall by remember { mutableStateOf(false) }

    /** Today's artwork first, then the ones not read yet, then the rest. Shuffled anew at each launch, then kept. */
    val artworkCount = content.artworks.size
    val order = rememberSaveable(artworkCount) {
        val random = Random(sessionSeed)
        val daily = content.artworkOfTheDay?.id
        val others = content.artworks.filter { it.id != daily }.shuffled(random)
        val completed = user.profile.completedLessons
        val unread = others.filter { it.id !in completed }
        val read = others.filter { it.id in completed }
        listOfNotNull(daily) + (unread + read).map { it.id }
    }
    val items = order.mapNotNull { content.artwork(it) }
        .filter { filter.matches(it, user.profile.completedLessons.contains(it.id)) }
    val dailyId = content.artworkOfTheDay?.id

    Box(Modifier.fillMaxSize().background(Palette.bg)) {
        // A new filter starts the feed again from the top.
        key(filter) {
            val pager = rememberPagerState { items.size + 1 }
            LaunchedEffect(pager) {
                var previous: Int? = null
                snapshotFlow { pager.currentPage }.distinctUntilChanged().collect { page ->
                    // A tick under the finger each time another artwork comes up.
                    if (previous != null) Haptics.rigid()
                    previous = page
                    items.getOrNull(page)?.let { Analytics.track("feed_artwork_viewed", mapOf("artwork" to it.id)) }
                    // The next paintings load while this one is on screen: no waiting when scrolling.
                    items.subList(minOf(page + 1, items.size), minOf(page + 4, items.size))
                        .map { it.image }.filter { it.startsWith("http") }
                        .forEach { context.imageLoader.enqueue(ImageRequest.Builder(context).data(it).build()) }
                }
            }
            VerticalPager(pager, Modifier.fillMaxSize().statusBarsPadding(), beyondViewportPageCount = 1) { index ->
                val art = items.getOrNull(index)
                if (art != null) {
                    FeedCard(
                        artwork = art,
                        isDaily = !filter.isActive && art.id == dailyId,
                        showHint = index == 0 && items.size > 1,
                        onOpen = { course = art },
                    )
                } else {
                    FeedEndCard(
                        filtered = filter.isActive,
                        empty = items.isEmpty(),
                        onClearFilter = { filter = FeedFilter() },
                        onReview = onReview,
                        onExplore = onExplore,
                    )
                }
            }
        }

        // MARK: Top bar
        Column(Modifier.fillMaxWidth().background(Palette.sky)) {
            // Blue header behind the buttons, up to the top of the screen.
            Spacer(Modifier.windowInsetsTopHeight(WindowInsets.statusBars))
            Row(
                Modifier.fillMaxWidth().padding(horizontal = 16.dp).padding(top = 6.dp, bottom = 10.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                BarButton(
                    if (pro.isPro) Icons.Rounded.WorkspacePremium else Icons.Outlined.WorkspacePremium,
                    if (pro.isPro) L("Artura Pro is active") else L("Discover Artura Pro"),
                    tint = if (pro.isPro) Palette.yellow else Palette.ink,
                ) { if (!pro.isPro) showPaywall = true }
                BarButton(Icons.Outlined.LibraryBooks, L("My library")) { sheet = FeedSheet.Library(LibraryTab.Favorites) }
                Spacer(Modifier.weight(1f))
                StreakChip(user.streak)
                Spacer(Modifier.weight(1f))
                BarButton(Icons.Rounded.History, L("History")) { sheet = FeedSheet.Library(LibraryTab.History) }
                BarButton(
                    Icons.Rounded.FilterList,
                    if (filter.isActive) L("Filter, %@ active", "${filter.count}") else L("Filter"),
                    badge = filter.count,
                ) { sheet = FeedSheet.Filter }
                BarButton(Icons.Rounded.Search, L("Search")) { sheet = FeedSheet.Search }
            }
        }
    }

    val open = course
    FullScreenCover(visible = open != null, onDismiss = { course = null }) {
        if (open != null) CourseFlow(open) { course = null }
    }
    FullScreenCover(visible = showPaywall, onDismiss = { showPaywall = false }) {
        PaywallScreen(onClose = { showPaywall = false })
    }
    // One sheet at a time; the last one shown stays drawn while it slides away.
    var shownSheet by remember { mutableStateOf(sheet) }
    if (sheet != null) shownSheet = sheet
    FeedSheetCover(visible = sheet != null, onDismiss = { sheet = null }) {
        when (val s = shownSheet) {
            FeedSheet.Filter -> FeedFilterSheet(filter) { Haptics.press(); filter = it; sheet = null }
            FeedSheet.Search -> FeedSearchSheet(onFilter = { filter = it; sheet = null })
            is FeedSheet.Library -> key(s.tab) { LibraryView(s.tab) }
            null -> {}
        }
    }
}

@Composable
private fun BarButton(icon: ImageVector, label: String, tint: Color = Palette.ink, badge: Int = 0, onClick: () -> Unit) {
    Box(Modifier.size(42.dp).pressable(haptic = false) { Haptics.tap(); onClick() }.semantics { contentDescription = label }) {
        Box(Modifier.size(42.dp).background(Color.White, CircleShape), contentAlignment = Alignment.Center) {
            Icon(icon, null, tint = tint, modifier = Modifier.size(21.dp))
        }
        if (badge > 0) {
            Box(
                Modifier.align(Alignment.TopEnd).offset(x = 3.dp, y = (-3).dp).size(18.dp).background(Palette.orange, CircleShape),
                contentAlignment = Alignment.Center,
            ) {
                Text("$badge", style = figtree(11, FontWeight.Bold), color = Color.White)
            }
        }
    }
}

// MARK: - One card of the feed

@Composable
fun FeedCard(artwork: Artwork, isDaily: Boolean = false, showHint: Boolean = false, onOpen: () -> Unit) {
    val user = LocalUser.current
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val liked = user.isFavorite(artwork.id)
    val saved = user.isSaved(artwork.id)
    val read = user.profile.completedLessons.contains(artwork.id)

    var zoomed by remember { mutableStateOf<ZoomTarget?>(null) }
    val burst = remember { Animatable(0f) }
    val infinite = rememberInfiniteTransition(label = "card")
    val drift by infinite.animateFloat(1f, 1.06f, infiniteRepeatable(tween(9000), RepeatMode.Reverse), label = "drift")
    val nudge by infinite.animateFloat(3f, -3f, infiniteRepeatable(tween(900), RepeatMode.Reverse), label = "nudge")

    fun likeWithBurst() {
        Haptics.success()
        if (!liked) user.toggleFavorite(artwork.id)
        scope.launch {
            burst.animateTo(1f, tween(200))
            delay(500)
            burst.animateTo(0f, tween(250))
        }
    }

    Column(Modifier.fillMaxSize().padding(horizontal = 24.dp).padding(bottom = 6.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        // Room for the top bar, which floats above the feed.
        Spacer(Modifier.height(68.dp))

        Box(
            Modifier
                .fillMaxWidth()
                .weight(1f)
                .heightIn(min = 160.dp)
                .clip(RoundedCornerShape(28.dp))
                .semantics { contentDescription = "${artwork.title}, ${artwork.artist}" }
                .pointerInput(artwork.id) {
                    detectTapGestures(
                        onDoubleTap = { likeWithBurst() },
                        onTap = {
                            // A tap opens the painting full screen, where it can be zoomed.
                            Haptics.tap()
                            zoomed = ZoomTarget(artwork)
                        },
                    )
                },
        ) {
            ArtImage(artwork.image, Modifier.fillMaxSize(), zoom = drift, anchor = artwork.focusPoint)
            if (isDaily) {
                Box(Modifier.align(Alignment.TopStart).padding(12.dp)) {
                    TagPill(L("Artwork of the day"), fill = Color.White, foreground = Palette.blueText)
                }
            }
            if (read) {
                Row(
                    Modifier.align(Alignment.TopEnd).padding(12.dp).height(28.dp).background(Palette.green, CircleShape).padding(horizontal = 10.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(5.dp),
                ) {
                    Icon(Icons.Rounded.Check, null, tint = Color.White, modifier = Modifier.size(14.dp))
                    Text(L("Read"), style = figtree(13, FontWeight.SemiBold), color = Color.White)
                }
            }
            // Heart that pops when the artwork is liked with a double tap.
            Icon(
                Icons.Rounded.Favorite, null, tint = Color.White,
                modifier = Modifier.align(Alignment.Center).size(110.dp)
                    .graphicsLayer {
                        val s = 0.4f + 0.6f * burst.value
                        scaleX = s; scaleY = s; alpha = 0.95f * burst.value
                    }
                    .shadow(0.dp),
            )
        }

        Column(Modifier.padding(top = 14.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(artwork.title, style = figtree(26, FontWeight.SemiBold), color = Palette.ink, textAlign = TextAlign.Center,
                maxLines = 2, overflow = TextOverflow.Ellipsis)
            Text(artwork.meta, style = figtree(15, FontWeight.Medium), color = Palette.muted, textAlign = TextAlign.Center)
            Text(artwork.teaser, style = figtree(15), color = Palette.muted, textAlign = TextAlign.Center,
                maxLines = 2, overflow = TextOverflow.Ellipsis, modifier = Modifier.padding(top = 2.dp))
        }

        PillButton(Modifier.padding(top = 14.dp), onClick = onOpen) {
            Text(if (read) L("Read the story again") else L("Discover the story"), style = AType.bodyStrong, color = Color.White)
            Spacer(Modifier.width(8.dp))
            Icon(Icons.AutoMirrored.Rounded.ArrowForward, null, tint = Color.White, modifier = Modifier.size(18.dp))
        }

        Row(Modifier.padding(top = 12.dp), horizontalArrangement = Arrangement.spacedBy(18.dp)) {
            RoundActionLabel(
                Icons.Rounded.IosShare, Modifier.pressable(haptic = false) { shareArtwork(context, artwork) },
                description = L("Share %@", artwork.title),
            )
            val likeScale by animateFloatAsState(if (liked) 1.06f else 1f, tween(200), label = "like")
            RoundActionLabel(
                if (liked) Icons.Rounded.Favorite else Icons.Rounded.FavoriteBorder,
                Modifier.graphicsLayer { scaleX = likeScale; scaleY = likeScale }
                    .pressable { Haptics.press(); user.toggleFavorite(artwork.id) },
                tint = if (liked) Palette.orange else Palette.ink,
                description = if (liked) L("Remove from favorites") else L("Add to favorites"),
            )
            val saveScale by animateFloatAsState(if (saved) 1.06f else 1f, tween(200), label = "save")
            RoundActionLabel(
                if (saved) Icons.Rounded.Bookmark else Icons.Rounded.BookmarkBorder,
                Modifier.graphicsLayer { scaleX = saveScale; scaleY = saveScale }
                    .pressable { Haptics.press(); user.toggleSaved(artwork.id) },
                tint = if (saved) Palette.blue else Palette.ink,
                description = if (saved) L("Remove from saved") else L("Save for later"),
            )
        }

        // Swipe hint under the first card.
        Icon(
            Icons.Rounded.KeyboardArrowUp, null, tint = Palette.muted,
            modifier = Modifier.padding(top = 4.dp).height(22.dp).width(30.dp)
                .graphicsLayer { translationY = nudge * density; alpha = if (showHint) 0.8f else 0f },
        )
    }

    val target = zoomed
    FullScreenCover(visible = target != null, onDismiss = { zoomed = null }) {
        if (target != null) ZoomViewer(target) { zoomed = null }
    }
}

// MARK: - Last card: nothing left to scroll

@Composable
fun FeedEndCard(filtered: Boolean, empty: Boolean, onClearFilter: () -> Unit, onReview: () -> Unit, onExplore: () -> Unit) {
    val title = when {
        empty -> L("Nothing here yet.")
        filtered -> L("That's all for this filter.")
        else -> L("You're all caught up.")
    }
    val detail = if (filtered) L("Clear the filter to see every artwork again.")
    else L("A new artwork arrives tomorrow. Until then, review what you've learned.")

    Column(Modifier.fillMaxSize().padding(horizontal = 24.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        Spacer(Modifier.weight(1f).heightIn(min = 70.dp))
        MascotBubble(150.dp) {
            Text(title, style = figtree(24, FontWeight.SemiBold), color = Palette.ink, textAlign = TextAlign.Center)
            Spacer(Modifier.height(6.dp))
            Text(detail, style = figtree(15), color = Palette.muted, textAlign = TextAlign.Center)
        }
        Spacer(Modifier.weight(1f).heightIn(min = 16.dp))
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            if (filtered) {
                PillButton(L("Clear the filter")) { Haptics.tap(); onClearFilter() }
            } else {
                PillButton(L("Review what I've learned")) { Haptics.press(); onReview() }
                PillButton(L("Explore movements"), style = PillStyle.Secondary) { Haptics.tap(); onExplore() }
            }
        }
        Spacer(Modifier.weight(1f).heightIn(min = 24.dp))
    }
}
