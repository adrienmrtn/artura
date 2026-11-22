import Foundation

/// The user's profile and progress, stored on the device.
final class UserStore: ObservableObject {
    struct Profile: Codable, Equatable {
        var onboarded = false
        var gender: String?
        var flashKnown: [String] = []
        var phoneHours: Double = 4
        var arts: [String] = ["peinture"]
        var goal: String?
        var level: String?
        var liked: [String] = []
        var movements: [String] = []
        var minutes = 5
        var firstCourse: String?
        var reminderMinutes = 510
        var reminderOn = false
        var avatar = 0
        var playedDays: [String] = []
        var opened: [String] = []
        var favorites: [String] = []
        var completedLessons: [String] = []
        var gamesWon = 0
        var appleUserId: String?
        var googleUserId: String?
        var firstName: String?
        /// Day (yyyy-MM-dd) each lesson was last completed.
        var lessonDays: [String: String]?
        /// Today's practice: the day it applies to and the number of questions already answered.
        var trainingDay: String?
        var trainingCount: Int?
        /// Réponses aux questions de l'onboarding (optionnelles : absentes des anciens profils).
        var unknownArt: String?
        var museumHabit: String?
        /// Motivations choisies à l'onboarding (plusieurs possibles).
        var goals: [String]?
        /// Artworks bookmarked from the feed ("save for later"), separate from favorites.
        var saved: [String]?
        /// Daily review: the day it was last completed.
        var reviewDay: String?
        /// The lesson a free reader can read in full today: the day, and the first lesson opened that day.
        var freeLessonDay: String?
        var freeLessonId: String?
    }

    @Published var profile: Profile {
        didSet { save() }
    }

    private let key = "artura.profile.v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode(Profile.self, from: data) {
            profile = decoded
        } else {
            profile = Profile()
        }
        OnboardingDebug.prepare(&profile)
        AppDebug.prepare(&profile)
    }

    private func save() {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    // MARK: Streak

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func dayKey(_ date: Date) -> String { dayFormatter.string(from: date) }

    var playedToday: Bool { profile.playedDays.contains(Self.dayKey(Date())) }

    /// Number of consecutive days, counting today or yesterday as the last day.
    var streak: Int {
        let days = Set(profile.playedDays)
        let cal = Calendar.current
        var cursor = Date()
        if !days.contains(Self.dayKey(cursor)) {
            guard let yesterday = cal.date(byAdding: .day, value: -1, to: cursor),
                  days.contains(Self.dayKey(yesterday)) else { return 0 }
            cursor = yesterday
        }
        var count = 0
        while days.contains(Self.dayKey(cursor)) {
            count += 1
            guard let previous = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }

    struct WeekDay: Identifiable {
        let id: Int
        let label: String
        let played: Bool
        let isToday: Bool
    }

    /// The 7 days of the current week (Monday → Sunday) with their state.
    var week: [WeekDay] {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        let today = Date()
        let labels = ["M", "T", "W", "T", "F", "S", "S"]
        guard let start = cal.dateInterval(of: .weekOfYear, for: today)?.start else { return [] }
        let days = Set(profile.playedDays)
        var result: [WeekDay] = []
        for i in 0..<7 {
            guard let d = cal.date(byAdding: .day, value: i, to: start) else { continue }
            result.append(WeekDay(id: i, label: labels[i], played: days.contains(Self.dayKey(d)), isToday: cal.isDate(d, inSameDayAs: today)))
        }
        return result
    }

    // MARK: Actions

    func markPlayedToday() {
        let k = Self.dayKey(Date())
        if !profile.playedDays.contains(k) { profile.playedDays.append(k) }
    }

    func recordGame(won: Bool) {
        markPlayedToday()
        if won { profile.gamesWon += 1 }
    }

    /// True if a free reader can read this lesson in full today.
    /// The first lesson opened in a day is the free one, and stays free all day.
    func claimFreeLesson(_ id: String) -> Bool {
        let today = Self.dayKey(Date())
        if profile.freeLessonDay != today {
            profile.freeLessonDay = today
            profile.freeLessonId = id
        }
        return profile.freeLessonId == id
    }

    func markOpened(_ id: String) {
        if !profile.opened.contains(id) { profile.opened.append(id) }
    }

    func completeLesson(_ id: String) {
        markOpened(id)
        if !profile.completedLessons.contains(id) { profile.completedLessons.append(id) }
        var days = profile.lessonDays ?? [:]
        days[id] = Self.dayKey(Date())
        profile.lessonDays = days
        markPlayedToday()
    }

    /// True if this lesson was completed today.
    func finishedToday(_ id: String) -> Bool {
        profile.lessonDays?[id] == Self.dayKey(Date())
    }

    // MARK: Today's practice

    static let trainingDailyGoal = 30

    var trainingDoneToday: Int {
        profile.trainingDay == Self.dayKey(Date()) ? (profile.trainingCount ?? 0) : 0
    }

    var trainingRemaining: Int { max(0, Self.trainingDailyGoal - trainingDoneToday) }

    var trainingFinished: Bool { trainingRemaining == 0 }

    func recordTrainingAnswer() {
        let count = trainingDoneToday + 1
        profile.trainingDay = Self.dayKey(Date())
        profile.trainingCount = count
    }

    func toggleFavorite(_ id: String) {
        if let i = profile.favorites.firstIndex(of: id) {
            profile.favorites.remove(at: i)
        } else {
            profile.favorites.append(id)
        }
    }

    func isFavorite(_ id: String) -> Bool { profile.favorites.contains(id) }

    // MARK: Saved artworks

    func toggleSaved(_ id: String) {
        var saved = profile.saved ?? []
        if let i = saved.firstIndex(of: id) {
            saved.remove(at: i)
        } else {
            saved.append(id)
        }
        profile.saved = saved
    }

    func isSaved(_ id: String) -> Bool { profile.saved?.contains(id) ?? false }

    // MARK: Daily review

    /// True if today's review has already been completed.
    var reviewDoneToday: Bool { profile.reviewDay == Self.dayKey(Date()) }

    func completeReview() {
        profile.reviewDay = Self.dayKey(Date())
        markPlayedToday()
    }

    func toggleLiked(_ id: String, limit: Int = 3) {
        if let i = profile.liked.firstIndex(of: id) {
            profile.liked.remove(at: i)
        } else if profile.liked.count < limit {
            profile.liked.append(id)
        }
    }

    func toggleMovement(_ id: String) {
        if let i = profile.movements.firstIndex(of: id) {
            profile.movements.remove(at: i)
        } else {
            profile.movements.append(id)
        }
    }

    /// Returns the masculine or feminine form, based on the answer to the gender step.
    func agree(_ masculine: String, _ feminine: String) -> String {
        profile.gender == "femme" ? feminine : masculine
    }

    func resetAll() {
        profile = Profile()
    }
}

/// Formats minutes since midnight (0..<1440) as a 12-hour time, e.g. "8:30 AM".
func formatMinutes(_ minutes: Int) -> String {
    let h = (minutes / 60) % 24
    let m = minutes % 60
    let h12 = h % 12 == 0 ? 12 : h % 12
    return "\(h12):\(m < 10 ? "0" : "")\(m) \(h < 12 ? "AM" : "PM")"
}
