package com.vikstudios.artura.main

import android.Manifest
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Refresh
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.UnfoldMore
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import com.vikstudios.artura.core.Appearance
import com.vikstudios.artura.services.Analytics
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
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
import com.vikstudios.artura.core.SkyHeader
import com.vikstudios.artura.core.figtree
import com.vikstudios.artura.core.hexColor
import com.vikstudios.artura.core.pressable
import com.vikstudios.artura.data.Artwork
import com.vikstudios.artura.data.Movement
import com.vikstudios.artura.data.avatarImages
import com.vikstudios.artura.data.formatMinutes
import com.vikstudios.artura.onboarding.AvatarPicker
import com.vikstudios.artura.onboarding.PaywallScreen
import com.vikstudios.artura.services.Reminder

@Composable
fun ProfileView() {
    val user = LocalUser.current
    val content = LocalContent.current
    val pro = LocalPro.current
    val context = LocalContext.current
    var course by remember { mutableStateOf<Artwork?>(null) }
    var showPaywall by remember { mutableStateOf(false) }
    var confirmReset by remember { mutableStateOf(false) }
    val scroll = rememberScrollState()

    LaunchedEffect(scroll.maxValue) {
        if (AppDebug.string("profileScroll") == "bottom") scroll.scrollTo(scroll.maxValue)
    }

    // The stored level is the English option title from onboarding: show it in the app's language.
    val levelName = when (val level = user.profile.level ?: "Enthusiast") {
        "Beginner" -> L("Beginner")
        "Enthusiast" -> L("Enthusiast")
        "Connoisseur" -> L("Connoisseur")
        else -> level
    }
    val levelLabel = L("%@ · level %@", levelName, "${1 + user.profile.completedLessons.size / 2}")

    val tastes: List<Pair<Movement, Int>> = run {
        val ids = user.profile.opened + user.profile.liked
        content.movements
            .map { m -> m to ids.count { content.artwork(it)?.movementId == m.id } }
            .filter { it.second > 0 }
            .sortedByDescending { it.second }
    }

    // Android 13+: the notification permission is asked when the reminder is turned on.
    val permission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        user.update { it.copy(reminderOn = granted) }
        if (granted) Reminder.scheduleDaily(context, user.profile.reminderMinutes)
    }

    Column(Modifier.fillMaxSize().background(Palette.bg).verticalScroll(scroll), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        SkyHeader(height = 190.dp) {
            Row(Modifier.padding(start = 24.dp, top = 60.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                AnimatedContent(
                    targetState = user.profile.avatar,
                    transitionSpec = { (scaleIn() + fadeIn()) togetherWith (scaleOut() + fadeOut()) },
                    label = "avatar",
                ) { avatar ->
                    ArtImage(avatarImages[minOf(avatar, avatarImages.size - 1)],
                        Modifier.size(76.dp).clip(CircleShape).border(3.dp, Color.White, CircleShape))
                }
                Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text(user.profile.firstName ?: L("Your profile"), style = figtree(24, FontWeight.SemiBold), color = Color.White)
                    Text(levelLabel, style = figtree(14), color = Color.White)
                }
            }
        }

        Column(
            Modifier.padding(horizontal = 24.dp).offset(y = (-16).dp).padding(bottom = 10.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Text(L("Choose your avatar"), style = AType.heading, color = Palette.ink)
            AvatarPicker(selection = user.profile.avatar, onSelect = { a -> user.update { it.copy(avatar = a) } }, size = 54.dp)

            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Stat("${user.streak}", L("day streak"), Palette.yellow, Modifier.weight(1f))
                Stat("${user.profile.opened.size}", L("artworks opened"), Palette.pink, Modifier.weight(1f))
                Stat("${user.profile.gamesWon}", L("games won"), Palette.mist, Modifier.weight(1f))
            }

            Text(L("My collection"), style = AType.heading, color = Palette.ink, modifier = Modifier.padding(top = 4.dp))
            Collection { course = it }

            if (tastes.isNotEmpty()) {
                Text(L("Your tastes"), style = AType.heading, color = Palette.ink, modifier = Modifier.padding(top = 4.dp))
                val maxCount = tastes.maxOf { it.second }
                Column(
                    Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(Palette.card).padding(horizontal = 16.dp, vertical = 14.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    tastes.forEach { (movement, count) ->
                        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                            Row {
                                Text(movement.name, style = figtree(14, FontWeight.SemiBold), color = Palette.ink, modifier = Modifier.weight(1f))
                                Text(if (count == 1) L("1 artwork") else L("%@ artworks", "$count"), style = AType.small, color = Palette.muted)
                            }
                            BoxWithConstraints(Modifier.fillMaxWidth().height(8.dp).clip(CircleShape).background(Palette.bg)) {
                                Box(Modifier.width(maxWidth * (count.toFloat() / maxCount)).height(8.dp).clip(CircleShape).background(Palette.blue))
                            }
                        }
                    }
                }
            }

            // Settings
            Column(Modifier.padding(top = 4.dp).fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(Palette.card).padding(horizontal = 16.dp)) {
                Row(Modifier.heightIn(min = 56.dp), verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                        Text(L("Daily reminder"), style = figtree(15, FontWeight.SemiBold), color = Palette.ink)
                        Text(formatMinutes(user.profile.reminderMinutes), style = AType.caption, color = Palette.muted)
                    }
                    Switch(
                        checked = user.profile.reminderOn,
                        onCheckedChange = { on ->
                            Haptics.selection()
                            if (on) {
                                if (Build.VERSION.SDK_INT >= 33 && !Reminder.isAllowed(context)) {
                                    permission.launch(Manifest.permission.POST_NOTIFICATIONS)
                                } else {
                                    user.update { it.copy(reminderOn = true) }
                                    Reminder.scheduleDaily(context, user.profile.reminderMinutes)
                                }
                            } else {
                                user.update { it.copy(reminderOn = false) }
                                Reminder.cancelDaily(context)
                            }
                        },
                        colors = SwitchDefaults.colors(checkedTrackColor = Palette.blue, checkedThumbColor = Color.White, uncheckedBorderColor = Palette.lip, uncheckedTrackColor = Palette.line),
                    )
                }
                HorizontalDivider(color = Palette.line)
                AppearanceRow()
                HorizontalDivider(color = Palette.line)
                Row(
                    Modifier.fillMaxWidth().heightIn(min = 56.dp).pressable { if (!pro.isPro) showPaywall = true },
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text("Artura Pro", style = figtree(15, FontWeight.SemiBold), color = Palette.ink, modifier = Modifier.weight(1f))
                    Text(if (pro.isPro) L("Active") else L("Try 3 days free"), style = AType.small, color = if (pro.isPro) Palette.green else Palette.blueText)
                }
                HorizontalDivider(color = Palette.line)
                Row(
                    Modifier.fillMaxWidth().heightIn(min = 56.dp).pressable { confirmReset = true },
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(L("Redo the intro"), style = figtree(15, FontWeight.SemiBold), color = Palette.ink, modifier = Modifier.weight(1f))
                    Icon(Icons.Rounded.Refresh, null, tint = Palette.muted, modifier = Modifier.size(20.dp))
                }
            }
            SupportSection()
        }
    }

    val shownCourse = course
    FullScreenCover(visible = shownCourse != null, onDismiss = { course = null }) {
        if (shownCourse != null) CourseFlow(shownCourse) { course = null }
    }
    FullScreenCover(visible = showPaywall, onDismiss = { showPaywall = false }) {
        PaywallScreen(onClose = { showPaywall = false })
    }

    if (confirmReset) {
        AlertDialog(
            onDismissRequest = { confirmReset = false },
            containerColor = Palette.bg,
            title = { Text(L("Start over from the beginning?"), style = AType.cardTitle, color = Palette.ink) },
            text = { Text(L("Your streak, collection, and answers will be erased from this device."), style = AType.body, color = Palette.muted) },
            confirmButton = {
                TextButton({
                    confirmReset = false
                    Haptics.warning()
                    Reminder.cancelDaily(context)
                    user.resetAll()
                }) { Text(L("Erase everything"), style = AType.bodyStrong, color = Palette.red) }
            },
            dismissButton = { TextButton({ confirmReset = false }) { Text(L("Cancel"), style = AType.bodyStrong, color = Palette.blueText) } },
        )
    }
}

@Composable
private fun Stat(value: String, label: String, color: Color, modifier: Modifier) {
    // Dark text on light fills (yellow and pink stay bright in dark mode), light text on dark ones.
    val ink = if (color.luminance() > 0.4f) hexColor(0x2D2C2B) else Palette.ink
    Column(modifier.clip(RoundedCornerShape(16.dp)).background(color).padding(12.dp), verticalArrangement = Arrangement.spacedBy(2.dp)) {
        AnimatedContent(value, transitionSpec = { (slideInVertically { it / 2 } + fadeIn()) togetherWith (slideOutVertically { -it / 2 } + fadeOut()) }, label = "stat") {
            Text(it, style = figtree(26, FontWeight.SemiBold), color = ink)
        }
        Text(label, style = figtree(13, FontWeight.Medium), color = ink, maxLines = 2)
    }
}

@Composable
private fun Collection(onOpen: (Artwork) -> Unit) {
    val user = LocalUser.current
    val content = LocalContent.current
    val items = user.profile.favorites.mapNotNull { content.artwork(it) }
    if (items.isEmpty()) {
        Text(
            L("Tap the heart on an artwork to add it to your collection."), style = AType.small, color = Palette.muted,
            modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(Palette.card).padding(16.dp),
        )
    } else {
        Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            items.forEach { art ->
                ArtImage(art.image, Modifier.size(104.dp).semantics { contentDescription = art.title }
                    .pressable { onOpen(art) }.clip(RoundedCornerShape(12.dp)), small = true)
            }
        }
    }
    Spacer(Modifier.height(0.dp))
}

/** "Appearance" row of the settings: light (default), dark, or the phone's setting. */
@Composable
private fun AppearanceRow() {
    var open by remember { mutableStateOf(false) }
    Row(
        Modifier.fillMaxWidth().heightIn(min = 56.dp).pressable { open = true },
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(L("Appearance"), style = figtree(15, FontWeight.SemiBold), color = Palette.ink, modifier = Modifier.weight(1f))
        Box {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(Appearance.current.title, style = AType.small, color = Palette.blueText)
                Icon(Icons.Rounded.UnfoldMore, null, tint = Palette.blueText, modifier = Modifier.size(16.dp))
            }
            DropdownMenu(expanded = open, onDismissRequest = { open = false }, containerColor = Palette.bg) {
                Appearance.entries.forEach { option ->
                    DropdownMenuItem(
                        text = { Text(option.title, style = AType.body, color = Palette.ink) },
                        trailingIcon = if (option == Appearance.current) {
                            { Icon(Icons.Rounded.Check, null, tint = Palette.blue) }
                        } else null,
                        onClick = {
                            open = false
                            if (option != Appearance.current) {
                                Haptics.selection()
                                Analytics.track("appearance_changed", mapOf("to" to option.key))
                                Appearance.set(option)
                            }
                        },
                    )
                }
            }
        }
    }
}
