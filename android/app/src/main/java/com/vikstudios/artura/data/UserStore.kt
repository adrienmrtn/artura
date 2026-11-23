package com.vikstudios.artura.data

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.vikstudios.artura.core.AppLanguage
import com.vikstudios.artura.services.Analytics
import com.vikstudios.artura.services.ProgressSync
import com.vikstudios.artura.services.SupabaseAuth
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.serialization.Serializable
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.LocalTime
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.time.format.TextStyle
import java.time.temporal.TemporalAdjusters

/**
 * The user's profile and progress. Same fields and JSON names as the iOS `UserStore.Profile`, so the
 * progress saved online (Supabase `user_progress`) is shared between an iPhone and an Android phone.
 */
@Serializable
data class Profile(
    val onboarded: Boolean = false,
    val gender: String? = null,
    val flashKnown: List<String> = emptyList(),
    val phoneHours: Double = 4.0,
    val arts: List<String> = listOf("peinture"),
    val goal: String? = null,
    val level: String? = null,
    val liked: List<String> = emptyList(),
    val movements: List<String> = emptyList(),
    val minutes: Int = 5,
    val firstCourse: String? = null,
    val reminderMinutes: Int = 510,
    val reminderOn: Boolean = false,
    val avatar: Int = 0,
    val playedDays: List<String> = emptyList(),
    val opened: List<String> = emptyList(),
    val favorites: List<String> = emptyList(),
    val completedLessons: List<String> = emptyList(),
    val gamesWon: Int = 0,
    val appleUserId: String? = null,
    val googleUserId: String? = null,
    val firstName: String? = null,
    /** Day (yyyy-MM-dd) each lesson was last completed. */
    val lessonDays: Map<String, String>? = null,
    /** Today's practice: the day it applies to and the number of questions already answered. */
    val trainingDay: String? = null,
    val trainingCount: Int? = null,
    /** Answers to the onboarding questions (optional: missing from older profiles). */
    val unknownArt: String? = null,
    val museumHabit: String? = null,
    /** Motivations chosen in the onboarding (several possible). */
    val goals: List<String>? = null,
    /** Artworks bookmarked from the feed ("save for later"), separate from favorites. */
    val saved: List<String>? = null,
    /** Daily review: the day it was last completed. */
    val reviewDay: String? = null,
    /** The lesson a free reader can read in full today: the day, and the first lesson opened that day. */
    val freeLessonDay: String? = null,
    val freeLessonId: String? = null,
) {
    /** This phone's profile combined with the one saved online: progress is added up, answers and settings of this phone win when they are set. */
    fun merged(other: Profile): Profile {
        fun union(a: List<String>, b: List<String>): List<String> {
            val seen = a.toMutableSet()
            return a + b.filter { seen.add(it) }
        }
        fun unionOpt(a: List<String>?, b: List<String>?): List<String>? =
            if (a == null && b == null) null else union(a ?: emptyList(), b ?: emptyList())
        fun later(a: String?, b: String?): String? = when {
            a == null -> b
            b == null -> a
            else -> maxOf(a, b)
        }
        var m = copy(
            onboarded = onboarded || other.onboarded,
            flashKnown = union(flashKnown, other.flashKnown),
            playedDays = union(playedDays, other.playedDays),
            opened = union(opened, other.opened),
            favorites = union(favorites, other.favorites),
            completedLessons = union(completedLessons, other.completedLessons),
            saved = unionOpt(saved, other.saved),
            gamesWon = maxOf(gamesWon, other.gamesWon),
            liked = liked.ifEmpty { other.liked },
            movements = movements.ifEmpty { other.movements },
            gender = gender ?: other.gender,
            goal = goal ?: other.goal,
            goals = goals ?: other.goals,
            level = level ?: other.level,
            firstCourse = firstCourse ?: other.firstCourse,
            firstName = firstName ?: other.firstName,
            unknownArt = unknownArt ?: other.unknownArt,
            museumHabit = museumHabit ?: other.museumHabit,
            appleUserId = appleUserId ?: other.appleUserId,
            googleUserId = googleUserId ?: other.googleUserId,
            reviewDay = later(reviewDay, other.reviewDay),
        )
        val days = (other.lessonDays ?: emptyMap()).toMutableMap()
        (lessonDays ?: emptyMap()).forEach { (id, day) -> days[id] = later(day, days[id])!! }
        m = m.copy(lessonDays = days.ifEmpty { null })
        val theirs = other.trainingDay
        if (theirs != null && theirs > (trainingDay ?: "")) {
            m = m.copy(trainingDay = theirs, trainingCount = other.trainingCount)
        } else if (trainingDay == other.trainingDay) {
            m = m.copy(trainingCount = maxOf(trainingCount ?: 0, other.trainingCount ?: 0))
        }
        val theirFree = other.freeLessonDay
        if (theirFree != null && theirFree > (freeLessonDay ?: "")) {
            m = m.copy(freeLessonDay = theirFree, freeLessonId = other.freeLessonId)
        }
        return m
    }

    /** The answers given so far in the onboarding (never the first name). */
    val onboardingAnswers: Map<String, Any?>
        get() = buildMap {
            put("phone_hours", phoneHours)
            put("arts", arts)
            put("minutes_per_day", minutes)
            put("reminder_on", reminderOn)
            put("reminder_minutes", reminderMinutes)
            put("avatar", avatar)
            put("flash_known", flashKnown)
            put("flash_known_count", flashKnown.size)
            put("has_first_name", !firstName.isNullOrEmpty())
            put("signed_in_apple", appleUserId != null)
            put("signed_in_google", googleUserId != null)
            gender?.let { put("gender", it) }
            goals?.let { put("goals", it) }
            goal?.let { put("goal", it) }
            level?.let { put("level", it) }
            unknownArt?.let { put("unknown_art", it) }
            museumHabit?.let { put("museum_habit", it) }
            firstCourse?.let { put("first_course", it) }
        }
}

/** The user's profile and progress, stored on the device. Observable from Compose. */
class UserStore(context: Context) {
    private val prefs = context.getSharedPreferences("artura", Context.MODE_PRIVATE)
    private val key = "artura.profile.v1"
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    private var _profile by mutableStateOf(load())

    /** Every change is saved at once, and sent to the account a couple of seconds later. */
    var profile: Profile
        get() = _profile
        set(value) {
            val old = _profile
            _profile = value
            save()
            if (value != old) scheduleUpload()
        }

    /** Changes the profile: `user.update { it.copy(minutes = 10) }`. */
    fun update(change: (Profile) -> Profile) { profile = change(profile) }

    /** "apple" or "google" when the progress is saved online (Supabase account), null otherwise. */
    var accountProvider by mutableStateOf(SupabaseAuth.provider)
        private set

    private fun load(): Profile = try {
        prefs.getString(key, null)?.let { AppJson.decodeFromString(Profile.serializer(), it) } ?: Profile()
    } catch (_: Exception) { Profile() }

    private fun save() {
        prefs.edit().putString(key, AppJson.encodeToString(Profile.serializer(), _profile)).apply()
    }

    /** Applies the debug launch arguments (sample profile, onboarding step). Debug builds only. */
    fun applyDebug(prepare: (Profile) -> Profile) {
        val prepared = prepare(_profile)
        if (prepared != _profile) { _profile = prepared; save() }
    }

    // MARK: Streak

    val playedToday: Boolean get() = profile.playedDays.contains(dayKey(LocalDate.now()))

    /** Number of consecutive days, counting today or yesterday as the last day. */
    val streak: Int
        get() {
            val days = profile.playedDays.toSet()
            var cursor = LocalDate.now()
            if (!days.contains(dayKey(cursor))) {
                val yesterday = cursor.minusDays(1)
                if (!days.contains(dayKey(yesterday))) return 0
                cursor = yesterday
            }
            var count = 0
            while (days.contains(dayKey(cursor))) {
                count++
                cursor = cursor.minusDays(1)
            }
            return count
        }

    data class WeekDay(val id: Int, val label: String, val played: Boolean, val isToday: Boolean)

    /** The 7 days of the current week (Monday → Sunday) with their state. */
    val week: List<WeekDay>
        get() {
            val today = LocalDate.now()
            val start = today.with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY))
            val days = profile.playedDays.toSet()
            return (0 until 7).map { i ->
                val d = start.plusDays(i.toLong())
                val label = d.dayOfWeek.getDisplayName(TextStyle.NARROW_STANDALONE, AppLanguage.locale)
                WeekDay(i, label, days.contains(dayKey(d)), d == today)
            }
        }

    // MARK: Actions

    fun markPlayedToday() {
        val k = dayKey(LocalDate.now())
        if (!profile.playedDays.contains(k)) update { it.copy(playedDays = it.playedDays + k) }
    }

    fun recordGame(won: Boolean) {
        Analytics.track("game_finished", mapOf("won" to won))
        markPlayedToday()
        if (won) update { it.copy(gamesWon = it.gamesWon + 1) }
    }

    /** True if a free reader can read this lesson in full today. The first lesson opened in a day is the free one, and stays free all day. */
    fun claimFreeLesson(id: String): Boolean {
        val today = dayKey(LocalDate.now())
        if (profile.freeLessonDay != today) update { it.copy(freeLessonDay = today, freeLessonId = id) }
        return profile.freeLessonId == id
    }

    fun markOpened(id: String) {
        if (!profile.opened.contains(id)) update { it.copy(opened = it.opened + id) }
    }

    fun completeLesson(id: String) {
        markOpened(id)
        update { p ->
            val days = (p.lessonDays ?: emptyMap()) + (id to dayKey(LocalDate.now()))
            p.copy(
                completedLessons = if (p.completedLessons.contains(id)) p.completedLessons else p.completedLessons + id,
                lessonDays = days,
            )
        }
        markPlayedToday()
    }

    /** True if this lesson was completed today. */
    fun finishedToday(id: String): Boolean = profile.lessonDays?.get(id) == dayKey(LocalDate.now())

    // MARK: Today's practice

    val trainingDoneToday: Int
        get() = if (profile.trainingDay == dayKey(LocalDate.now())) profile.trainingCount ?: 0 else 0

    val trainingRemaining: Int get() = maxOf(0, TRAINING_DAILY_GOAL - trainingDoneToday)
    val trainingFinished: Boolean get() = trainingRemaining == 0

    fun recordTrainingAnswer() {
        val count = trainingDoneToday + 1
        update { it.copy(trainingDay = dayKey(LocalDate.now()), trainingCount = count) }
    }

    fun toggleFavorite(id: String) {
        Analytics.track("favorite_toggled", mapOf("artwork" to id, "on" to !profile.favorites.contains(id)))
        update { p -> p.copy(favorites = if (p.favorites.contains(id)) p.favorites - id else p.favorites + id) }
    }

    fun isFavorite(id: String) = profile.favorites.contains(id)

    // MARK: Saved artworks

    fun toggleSaved(id: String) {
        Analytics.track("saved_toggled", mapOf("artwork" to id, "on" to !(profile.saved?.contains(id) ?: false)))
        update { p ->
            val saved = p.saved ?: emptyList()
            p.copy(saved = if (saved.contains(id)) saved - id else saved + id)
        }
    }

    fun isSaved(id: String) = profile.saved?.contains(id) ?: false

    // MARK: Daily review

    /** True if today's review has already been completed. */
    val reviewDoneToday: Boolean get() = profile.reviewDay == dayKey(LocalDate.now())

    fun completeReview() {
        Analytics.track("review_completed")
        update { it.copy(reviewDay = dayKey(LocalDate.now())) }
        markPlayedToday()
    }

    fun toggleLiked(id: String, limit: Int = 3) {
        update { p ->
            when {
                p.liked.contains(id) -> p.copy(liked = p.liked - id)
                p.liked.size < limit -> p.copy(liked = p.liked + id)
                else -> p
            }
        }
    }

    fun toggleMovement(id: String) {
        update { p -> p.copy(movements = if (p.movements.contains(id)) p.movements - id else p.movements + id) }
    }

    /** Returns the masculine or feminine form, based on the answer to the gender step. */
    fun agree(masculine: String, feminine: String) = if (profile.gender == "femme") feminine else masculine

    fun resetAll() { profile = Profile() }

    // MARK: Account (progress saved online)

    private var uploadJob: Job? = null

    /** Sends the profile a couple of seconds after the last change (several changes, one request). */
    private fun scheduleUpload() {
        if (accountProvider == null) return
        uploadJob?.cancel()
        val snapshot = profile
        uploadJob = scope.launch {
            delay(2000)
            val session = SupabaseAuth.validSession() ?: return@launch
            runCatching { ProgressSync.push(snapshot, session) }
        }
    }

    /** After Google sign-in: opens (or creates) the Supabase account, brings back the progress saved online and combines it with this phone's. */
    suspend fun connectAccount(provider: String, idToken: String, nonce: String?) {
        try {
            val session = SupabaseAuth.signIn(provider, idToken, nonce)
            accountProvider = provider
            Analytics.track("account_connected", mapOf("provider" to provider))
            pullAndMerge(session)
        } catch (_: Exception) {
            Analytics.track("account_failed", mapOf("provider" to provider))
        }
    }

    /** At launch and when the app comes back: brings in what was saved from another phone. */
    suspend fun refreshFromAccount() {
        if (accountProvider == null) return
        val session = SupabaseAuth.validSession()
        if (session == null) {
            accountProvider = SupabaseAuth.provider
            return
        }
        pullAndMerge(session)
    }

    private suspend fun pullAndMerge(session: SupabaseAuth.Session) {
        val remote = runCatching { ProgressSync.pull(session) }.getOrElse { return }
        if (remote == null) {
            runCatching { ProgressSync.push(profile, session) }
            return
        }
        val merged = profile.merged(remote)
        if (merged != profile) profile = merged
        if (merged != remote) runCatching { ProgressSync.push(merged, session) }
    }

    /** Signs out: the progress stays on this phone, and stays saved online for the next sign-in. */
    suspend fun signOut() {
        uploadJob?.cancel()
        SupabaseAuth.signOut()
        accountProvider = null
        Analytics.track("account_signed_out")
    }

    /** Deletes the account and its online copy. The progress stays on this phone. Throws if offline. */
    suspend fun deleteAccount() {
        uploadJob?.cancel()
        SupabaseAuth.deleteAccount()
        accountProvider = null
        update { it.copy(appleUserId = null, googleUserId = null) }
        Analytics.track("account_deleted")
    }

    companion object {
        const val TRAINING_DAILY_GOAL = 30
        private val dayFormatter = DateTimeFormatter.ofPattern("yyyy-MM-dd")
        fun dayKey(date: LocalDate): String = date.format(dayFormatter)
    }
}

/** Formats minutes since midnight (0..<1440) as a time in the app's language, e.g. "8:30 AM" in English, "08:30" in French. */
fun formatMinutes(minutes: Int): String {
    val time = LocalTime.of((minutes / 60) % 24, minutes % 60)
    return time.format(DateTimeFormatter.ofLocalizedTime(FormatStyle.SHORT).withLocale(AppLanguage.locale))
}
