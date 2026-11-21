import Foundation

/// Profil et progression de l'utilisateur, stockés sur l'appareil.
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
        var firstName: String?
        /// Jour (yyyy-MM-dd) où chaque cours a été terminé pour la dernière fois.
        var lessonDays: [String: String]?
        /// Entraînement du jour : le jour concerné et le nombre de questions déjà répondues.
        var trainingDay: String?
        var trainingCount: Int?
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
    }

    private func save() {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    // MARK: Série

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func dayKey(_ date: Date) -> String { dayFormatter.string(from: date) }

    var playedToday: Bool { profile.playedDays.contains(Self.dayKey(Date())) }

    /// Nombre de jours consécutifs, en comptant aujourd'hui ou hier comme dernier jour.
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

    /// Les 7 jours de la semaine en cours (lundi → dimanche) avec leur état.
    var week: [WeekDay] {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        let today = Date()
        let labels = ["L", "M", "M", "J", "V", "S", "D"]
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

    /// Vrai si ce cours a été terminé aujourd'hui.
    func finishedToday(_ id: String) -> Bool {
        profile.lessonDays?[id] == Self.dayKey(Date())
    }

    // MARK: Entraînement du jour

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

    /// "prêt" ou "prête" selon la réponse à l'étape « Tu es… ».
    func agree(_ masculine: String, _ feminine: String) -> String {
        profile.gender == "femme" ? feminine : masculine
    }

    func resetAll() {
        profile = Profile()
    }
}

func formatMinutes(_ minutes: Int) -> String {
    let h = minutes / 60
    let m = minutes % 60
    return "\(h) h \(m < 10 ? "0" : "")\(m)"
}
