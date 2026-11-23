package com.vikstudios.artura.main

import android.app.TimePickerDialog
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.text.format.DateFormat
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.KeyboardArrowRight
import androidx.compose.material.icons.rounded.AccountCircle
import androidx.compose.material.icons.rounded.Email
import androidx.compose.material.icons.rounded.Language
import androidx.compose.material.icons.rounded.Lightbulb
import androidx.compose.material.icons.rounded.LibraryBooks
import androidx.compose.material.icons.rounded.Notifications
import androidx.compose.material.icons.rounded.Share
import androidx.compose.material.icons.rounded.Star
import androidx.compose.material.icons.rounded.Widgets
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.vikstudios.artura.app.AppDebug
import com.vikstudios.artura.app.LocalUser
import com.vikstudios.artura.core.AType
import com.vikstudios.artura.core.AppLanguage
import com.vikstudios.artura.core.CheckBadge
import com.vikstudios.artura.core.Haptics
import com.vikstudios.artura.core.L
import com.vikstudios.artura.core.Palette
import com.vikstudios.artura.core.figtree
import com.vikstudios.artura.core.pressable
import com.vikstudios.artura.feed.AppLinks
import com.vikstudios.artura.onboarding.SignInButtons
import com.vikstudios.artura.services.Reminder
import com.vikstudios.artura.widget.WidgetGuideView
import kotlinx.coroutines.launch

/** Profile rows added under the settings: library, widget, reminder time, language, and ways to support the app. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SupportSection() {
    val user = LocalUser.current
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var showLibrary by remember { mutableStateOf(false) }
    var showSignIn by remember { mutableStateOf(false) }
    var showAccountMenu by remember { mutableStateOf(false) }
    var showLanguages by remember { mutableStateOf(false) }
    var confirmDelete by remember { mutableStateOf(false) }
    var accountError by remember { mutableStateOf<String?>(null) }
    var showWidget by remember { mutableStateOf(AppDebug.string("profileSheet") == "widget") }

    val accountDetail = when (user.accountProvider) {
        "apple" -> L("Signed in with Apple")
        "google" -> L("Signed in with Google")
        else -> L("Save your progress online")
    }

    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Text(L("Settings"), style = AType.heading, color = Palette.ink, modifier = Modifier.padding(top = 4.dp))

        Card {
            SettingRow(Icons.Rounded.LibraryBooks, L("My library"), L("Favorites, saved and history")) { Haptics.tap(); showLibrary = true }
            HorizontalDivider(color = Palette.line)
            SettingRow(Icons.Rounded.Widgets, L("Widget"), L("The artwork of the day on your Home Screen")) { Haptics.tap(); showWidget = true }
            HorizontalDivider(color = Palette.line)
            // Reminder time: the system time picker, in the app's language.
            Row(
                Modifier.fillMaxWidth().heightIn(min = 56.dp).pressable { pickTime(context, user.profile.reminderMinutes) { minutes ->
                    user.update { it.copy(reminderMinutes = minutes) }
                    if (user.profile.reminderOn) Reminder.scheduleDaily(context, minutes)
                } },
                verticalAlignment = Alignment.CenterVertically,
            ) {
                RowLabel(Icons.Rounded.Notifications, L("Reminder time"), if (user.profile.reminderOn) L("Every day") else L("Reminder is off"), Modifier.weight(1f))
                Text(
                    com.vikstudios.artura.data.formatMinutes(user.profile.reminderMinutes), style = figtree(15, FontWeight.SemiBold), color = Palette.ink,
                    modifier = Modifier.clip(RoundedCornerShape(8.dp)).background(Palette.line).padding(horizontal = 10.dp, vertical = 6.dp),
                )
            }
            HorizontalDivider(color = Palette.line)
            SettingRow(Icons.Rounded.Language, L("Language"), AppLanguage.name(AppLanguage.code)) { Haptics.tap(); showLanguages = true }
            HorizontalDivider(color = Palette.line)
            SettingRow(Icons.Rounded.AccountCircle, if (user.accountProvider == null) L("Sign in") else L("Account"), accountDetail) {
                Haptics.tap()
                if (user.accountProvider == null) showSignIn = true else showAccountMenu = true
            }
        }

        Text(L("Support Artura"), style = AType.heading, color = Palette.ink, modifier = Modifier.padding(top = 4.dp))

        Card {
            SettingRow(Icons.Rounded.Share, L("Share Artura"), L("Learn art with your friends")) {
                var text = L("I'm learning art with Artura: one masterpiece a day, and the story behind it.")
                AppLinks.playStore?.let { text += " $it" }
                val send = Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT, text)
                context.startActivity(Intent.createChooser(send, null))
            }
            HorizontalDivider(color = Palette.line)
            SettingRow(Icons.Rounded.Star, L("Rate the app"), L("It really helps")) { Haptics.tap(); openStorePage(context) }
            if (AppLinks.supportEmail.isNotEmpty()) {
                HorizontalDivider(color = Palette.line)
                SettingRow(Icons.Rounded.Lightbulb, L("Request a feature"), L("Tell us what you'd like to see")) {
                    Haptics.tap(); mail(context, L("A feature idea for Artura"))
                }
                HorizontalDivider(color = Palette.line)
                SettingRow(Icons.Rounded.Email, L("Support"), AppLinks.supportEmail) { Haptics.tap(); mail(context, L("Artura support")) }
            }
        }
    }

    if (showWidget) {
        ModalBottomSheet({ showWidget = false }, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true), containerColor = Palette.bg) {
            WidgetGuideView(onDone = { showWidget = false })
        }
    }
    if (showLibrary) {
        ModalBottomSheet({ showLibrary = false }, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true), containerColor = Palette.bg) {
            LibrarySheet(onClose = { showLibrary = false })
        }
    }
    if (showSignIn) {
        ModalBottomSheet({ showSignIn = false }, containerColor = Palette.bg) { SignInSheet(onDone = { showSignIn = false }) }
    }
    if (showLanguages) {
        ModalBottomSheet({ showLanguages = false }, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true), containerColor = Palette.bg) {
            LanguageList { code ->
                showLanguages = false
                AppLanguage.set(code)
            }
        }
    }
    if (showAccountMenu) {
        AlertDialog(
            onDismissRequest = { showAccountMenu = false },
            containerColor = Palette.bg,
            title = { Text(L("Account"), style = AType.cardTitle, color = Palette.ink) },
            text = {
                Column {
                    TextButton({ showAccountMenu = false; scope.launch { user.signOut() } }) { Text(L("Sign out"), style = AType.bodyStrong, color = Palette.blueText) }
                    TextButton({ showAccountMenu = false; confirmDelete = true }) { Text(L("Delete my account"), style = AType.bodyStrong, color = Palette.red) }
                }
            },
            confirmButton = { TextButton({ showAccountMenu = false }) { Text(L("Cancel"), style = AType.bodyStrong, color = Palette.blueText) } },
        )
    }
    if (confirmDelete) {
        AlertDialog(
            onDismissRequest = { confirmDelete = false },
            containerColor = Palette.bg,
            title = { Text(L("Delete your account?"), style = AType.cardTitle, color = Palette.ink) },
            text = { Text(L("Your progress saved online will be deleted. It stays on this phone."), style = AType.body, color = Palette.muted) },
            confirmButton = {
                TextButton({
                    confirmDelete = false
                    scope.launch {
                        try {
                            user.deleteAccount()
                        } catch (_: Exception) {
                            accountError = L("Couldn't delete the account. Check your connection and try again.")
                        }
                    }
                }) { Text(L("Delete"), style = AType.bodyStrong, color = Palette.red) }
            },
            dismissButton = { TextButton({ confirmDelete = false }) { Text(L("Cancel"), style = AType.bodyStrong, color = Palette.blueText) } },
        )
    }
    accountError?.let { message ->
        AlertDialog(
            onDismissRequest = { accountError = null },
            containerColor = Palette.bg,
            title = { Text(message, style = AType.bodyStrong, color = Palette.ink) },
            confirmButton = { TextButton({ accountError = null }) { Text(L("OK"), style = AType.bodyStrong, color = Palette.blueText) } },
        )
    }
}

@Composable
private fun Card(content: @Composable () -> Unit) {
    Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(Palette.card).padding(horizontal = 16.dp)) { content() }
}

@Composable
private fun RowLabel(icon: ImageVector, title: String, detail: String, modifier: Modifier = Modifier) {
    Row(modifier, verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Box(Modifier.size(32.dp).clip(CircleShape).background(Palette.mist), contentAlignment = Alignment.Center) {
            Icon(icon, null, tint = Palette.blue, modifier = Modifier.size(17.dp))
        }
        Column(verticalArrangement = Arrangement.spacedBy(1.dp)) {
            Text(title, style = figtree(15, FontWeight.SemiBold), color = Palette.ink)
            Text(detail, style = AType.caption, color = Palette.muted, maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
    }
}

@Composable
private fun SettingRow(icon: ImageVector, title: String, detail: String, onClick: () -> Unit) {
    Row(Modifier.fillMaxWidth().heightIn(min = 56.dp).pressable(onClick = onClick), verticalAlignment = Alignment.CenterVertically) {
        RowLabel(icon, title, detail, Modifier.weight(1f))
        Icon(Icons.AutoMirrored.Rounded.KeyboardArrowRight, null, tint = Palette.muted, modifier = Modifier.size(20.dp))
    }
}

private fun pickTime(context: Context, minutes: Int, onPick: (Int) -> Unit) {
    val themed = AppLanguage.wrap(context)
    TimePickerDialog(themed, { _, h, m -> onPick(h * 60 + m) }, minutes / 60, minutes % 60, DateFormat.is24HourFormat(context)).show()
}

private fun mail(context: Context, subject: String) {
    val uri = Uri.parse("mailto:${AppLinks.supportEmail}?subject=${Uri.encode(subject)}")
    try { context.startActivity(Intent(Intent.ACTION_SENDTO, uri)) } catch (_: ActivityNotFoundException) {}
}

private fun openStorePage(context: Context) {
    val id = context.packageName
    try {
        context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=$id")))
    } catch (_: ActivityNotFoundException) {
        context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://play.google.com/store/apps/details?id=$id")))
    }
}

/** The app's languages, each in its own language; the current one is checked. */
@Composable
private fun LanguageList(onPick: (String) -> Unit) {
    LazyColumn(Modifier.fillMaxWidth().padding(horizontal = 24.dp).navigationBarsPadding()) {
        item { Text(L("Language"), style = figtree(24, FontWeight.SemiBold), color = Palette.ink, modifier = Modifier.padding(bottom = 12.dp)) }
        items(AppLanguage.all) { code ->
            Row(
                Modifier.fillMaxWidth().heightIn(min = 52.dp).pressable { Haptics.selection(); onPick(code) },
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(AppLanguage.name(code), style = AType.bodyStrong, color = Palette.ink, modifier = Modifier.weight(1f))
                if (code == AppLanguage.code) CheckBadge(size = 24.dp)
            }
            HorizontalDivider(color = Palette.line)
        }
    }
}

/** Sign in from the profile, for those who skipped it in the onboarding. */
@Composable
fun SignInSheet(onDone: () -> Unit) {
    var message by remember { mutableStateOf<String?>(null) }
    Column(
        Modifier.fillMaxWidth().padding(horizontal = 24.dp).padding(top = 12.dp, bottom = 24.dp).navigationBarsPadding(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(18.dp),
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(L("Save your progress"), style = figtree(24, FontWeight.SemiBold), color = Palette.ink, textAlign = TextAlign.Center)
            // The iOS sentence names the iPhone: on Android, any smartphone.
            Text(L("Your streak, lessons and collection come back on any iPhone.").replace("iPhone", "smartphone"),
                style = AType.body, color = Palette.muted, textAlign = TextAlign.Center)
        }
        message?.let { Text(it, style = AType.caption, color = Palette.red, textAlign = TextAlign.Center) }
        SignInButtons(message = message, onMessage = { message = it }, onDone = onDone)
    }
}
