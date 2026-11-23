import CryptoKit
import Foundation
import Security

/// The user's account, with Supabase Auth: Apple or Google gives an identity token, Supabase checks it and
/// creates (or finds) the user, and returns a session. The session is kept in the Keychain.
/// No SDK: a few calls to the Auth and REST APIs.
enum SupabaseAuth {
    struct Session: Codable, Equatable {
        var accessToken: String
        var refreshToken: String
        /// Seconds since 1970.
        var expiresAt: Double
        var userId: String
        /// "apple" or "google".
        var provider: String
    }

    enum Failure: Error {
        case rejected(String)
        case invalidResponse
    }

    private static var base: String { RemoteCatalog.base }
    private static var anonKey: String { RemoteCatalog.publicKey }

    // MARK: Sign in

    /// Exchanges an Apple or Google identity token for a Supabase session.
    /// `nonce` is the raw nonce whose SHA-256 was given to Apple (nil for Google).
    static func signIn(provider: String, idToken: String, nonce: String?) async throws -> Session {
        var body: [String: Any] = ["provider": provider, "id_token": idToken]
        if let nonce { body["nonce"] = nonce }
        let json = try await post("/auth/v1/token?grant_type=id_token", body: body, bearer: anonKey)
        let session = try session(from: json, provider: provider)
        store(session)
        return session
    }

    /// The saved session, refreshed if it expires within a minute. Nil when signed out or when it cannot be refreshed.
    static func validSession() async -> Session? {
        guard let saved = load() else { return nil }
        if saved.expiresAt > Date().timeIntervalSince1970 + 60 { return saved }
        do {
            let json = try await post("/auth/v1/token?grant_type=refresh_token",
                                      body: ["refresh_token": saved.refreshToken], bearer: anonKey)
            let fresh = try session(from: json, provider: saved.provider)
            store(fresh)
            return fresh
        } catch Failure.rejected {
            clear() // The refresh token is no longer valid: signed out.
            return nil
        } catch {
            return nil // Offline: try again later.
        }
    }

    static var isSignedIn: Bool { load() != nil }
    static var provider: String? { load()?.provider }

    static func signOut() async {
        if let session = load() {
            _ = try? await post("/auth/v1/logout", body: [:], bearer: session.accessToken)
        }
        clear()
    }

    /// Deletes the account and everything saved online (Edge Function `delete-account`), then signs out.
    static func deleteAccount() async throws {
        guard let session = await validSession() else { throw Failure.invalidResponse }
        _ = try await post("/functions/v1/delete-account", body: [:], bearer: session.accessToken)
        clear()
    }

    // MARK: Apple nonce

    /// A random nonce, and its SHA-256 (hex) to give to Apple.
    static func makeNonce() -> (raw: String, hashed: String) {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let raw = bytes.map { String(format: "%02x", $0) }.joined()
        let hashed = SHA256.hash(data: Data(raw.utf8)).map { String(format: "%02x", $0) }.joined()
        return (raw, hashed)
    }

    // MARK: Requests

    @discardableResult
    static func post(_ path: String, body: [String: Any], bearer: String) async throws -> [String: Any] {
        guard let url = URL(string: base + path) else { throw Failure.invalidResponse }
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        guard (200..<300).contains(status) else {
            let reason = json["error_description"] as? String ?? json["msg"] as? String ?? json["message"] as? String
            throw Failure.rejected(reason ?? "HTTP \(status)")
        }
        return json
    }

    private static func session(from json: [String: Any], provider: String) throws -> Session {
        guard let access = json["access_token"] as? String,
              let refresh = json["refresh_token"] as? String,
              let user = json["user"] as? [String: Any],
              let id = user["id"] as? String else { throw Failure.invalidResponse }
        let expiresIn = (json["expires_in"] as? Double) ?? 3600
        let expiresAt = (json["expires_at"] as? Double) ?? Date().timeIntervalSince1970 + expiresIn
        return Session(accessToken: access, refreshToken: refresh, expiresAt: expiresAt, userId: id, provider: provider)
    }

    // MARK: Keychain

    private static let account = "supabase.session"

    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "com.vikstudios.artura",
         kSecAttrAccount as String: account]
    }

    private static func store(_ session: Session) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        SecItemDelete(query as CFDictionary)
        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(item as CFDictionary, nil)
    }

    private static func load() -> Session? {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(request as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(Session.self, from: data)
    }

    private static func clear() {
        SecItemDelete(query as CFDictionary)
    }
}

/// The profile and progress saved online: one row per user in `user_progress`, readable and writable
/// only by its owner (row level security). The phone stays the reference; the online copy lets the
/// progress come back on another iPhone or after reinstalling.
enum ProgressSync {
    private struct Row: Codable {
        let profile: UserStore.Profile
    }

    /// The saved profile of the signed-in user (nil if there is none yet).
    static func pull(_ session: SupabaseAuth.Session) async throws -> UserStore.Profile? {
        let path = "/rest/v1/user_progress?select=profile&user_id=eq.\(session.userId)"
        guard let url = URL(string: RemoteCatalog.base + path) else { return nil }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.setValue(RemoteCatalog.publicKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode([Row].self, from: data).first?.profile
    }

    static func push(_ profile: UserStore.Profile, _ session: SupabaseAuth.Session) async throws {
        let path = "/rest/v1/user_progress?on_conflict=user_id"
        guard let url = URL(string: RemoteCatalog.base + path) else { return }
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("resolution=merge-duplicates,return=minimal", forHTTPHeaderField: "Prefer")
        request.setValue(RemoteCatalog.publicKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        struct Upsert: Encodable {
            let user_id: String
            let profile: UserStore.Profile
            let updated_at: String
        }
        let now = ISO8601DateFormatter().string(from: Date())
        request.httpBody = try JSONEncoder().encode(Upsert(user_id: session.userId, profile: profile, updated_at: now))
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let status = (response as? HTTPURLResponse)?.statusCode, (200..<300).contains(status) else {
            throw URLError(.badServerResponse)
        }
    }
}

extension UserStore.Profile {
    /// This phone's profile combined with the one saved online: progress is added up (days played,
    /// lessons, favorites, collection…), answers and settings of this phone win when they are set.
    func merged(with other: UserStore.Profile) -> UserStore.Profile {
        func union(_ a: [String], _ b: [String]) -> [String] {
            var seen = Set(a)
            return a + b.filter { seen.insert($0).inserted }
        }
        func union(_ a: [String]?, _ b: [String]?) -> [String]? {
            guard a != nil || b != nil else { return nil }
            return union(a ?? [], b ?? [])
        }
        func later(_ a: String?, _ b: String?) -> String? {
            guard let a else { return b }
            guard let b else { return a }
            return max(a, b)
        }

        var m = self
        m.onboarded = onboarded || other.onboarded
        m.flashKnown = union(flashKnown, other.flashKnown)
        m.playedDays = union(playedDays, other.playedDays)
        m.opened = union(opened, other.opened)
        m.favorites = union(favorites, other.favorites)
        m.completedLessons = union(completedLessons, other.completedLessons)
        m.saved = union(saved, other.saved)
        m.gamesWon = max(gamesWon, other.gamesWon)
        if liked.isEmpty { m.liked = other.liked }
        if movements.isEmpty { m.movements = other.movements }
        m.gender = gender ?? other.gender
        m.goal = goal ?? other.goal
        m.goals = goals ?? other.goals
        m.level = level ?? other.level
        m.firstCourse = firstCourse ?? other.firstCourse
        m.firstName = firstName ?? other.firstName
        m.unknownArt = unknownArt ?? other.unknownArt
        m.museumHabit = museumHabit ?? other.museumHabit
        m.appleUserId = appleUserId ?? other.appleUserId
        m.googleUserId = googleUserId ?? other.googleUserId
        var days = other.lessonDays ?? [:]
        for (id, day) in lessonDays ?? [:] { days[id] = later(day, days[id]) }
        m.lessonDays = days.isEmpty ? nil : days
        m.reviewDay = later(reviewDay, other.reviewDay)
        if let theirs = other.trainingDay, theirs > (trainingDay ?? "") {
            m.trainingDay = theirs
            m.trainingCount = other.trainingCount
        } else if trainingDay == other.trainingDay {
            m.trainingCount = max(trainingCount ?? 0, other.trainingCount ?? 0)
        }
        if let theirs = other.freeLessonDay, theirs > (freeLessonDay ?? "") {
            m.freeLessonDay = theirs
            m.freeLessonId = other.freeLessonId
        }
        return m
    }
}
