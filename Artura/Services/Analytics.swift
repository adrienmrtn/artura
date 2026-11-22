import Foundation

/// Anonymous usage events, stored in the online database (table `app_events`).
///
/// Each device gets a random identifier; nothing else identifies the person (no name, no e-mail,
/// no Apple or Google account). Events are queued, kept on the device until sent, and sent in batches.
/// Can be called from anywhere: the queue is handled on its own serial thread.
enum Analytics {
    /// Values allowed in an event's properties.
    typealias Properties = [String: Any]

    private static let deviceKey = "artura.analytics.device"
    private static let queueKey = "artura.analytics.queue"
    private static let batchSize = 25
    private static let maxQueue = 2000

    /// Random, per installation.
    static let deviceId: String = {
        if let saved = UserDefaults.standard.string(forKey: deviceKey) { return saved }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: deviceKey)
        return id
    }()

    /// Changes at each launch of the app.
    static let sessionId = UUID().uuidString

    /// Set from the subscription status, sent with every event.
    static var isPro: Bool {
        get { worker.sync { pro } }
        set { worker.async { pro = newValue } }
    }
    private static var pro = false
    private static let worker = DispatchQueue(label: "artura.analytics")

    private static var queue: [[String: Any]] = {
        guard let data = UserDefaults.standard.data(forKey: queueKey),
              let saved = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        return saved
    }()
    private static var sending = false
    private static var flushScheduled = false

    private static let appVersion: String = {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }()

    private static let osVersion: String = {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
    }()

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    /// Records an event. Properties hold plain values: strings, numbers, booleans, arrays and dictionaries of those.
    static func track(_ name: String, _ properties: Properties = [:]) {
        let date = Date()
        let language = AppLanguage.code
        worker.async { enqueue(name, properties, date: date, language: language) }
    }

    private static func enqueue(_ name: String, _ properties: Properties, date: Date, language: String) {
        #if DEBUG
        // Screenshots and runs launched with debug arguments stay out of the statistics.
        if ProcessInfo.processInfo.arguments.contains(where: { $0.hasPrefix("-onb") || $0 == "-demoProfile" || $0 == "-appTab" }) {
            return
        }
        #endif
        var row: [String: Any] = [
            "occurred_at": isoFormatter.string(from: date),
            "device_id": deviceId,
            "session_id": sessionId,
            "name": name,
            "properties": clean(properties),
            "language": language,
            "app_version": appVersion,
            "os_version": osVersion,
            "is_pro": pro
        ]
        if !JSONSerialization.isValidJSONObject(row) { row["properties"] = [:] as [String: Any] }
        queue.append(row)
        if queue.count > maxQueue { queue.removeFirst(queue.count - maxQueue) }
        save()
        if queue.count >= batchSize {
            send()
        } else if !flushScheduled {
            flushScheduled = true
            worker.asyncAfter(deadline: .now() + 8) {
                flushScheduled = false
                send()
            }
        }
    }

    /// Sends what is waiting. Called regularly, and when the app goes to the background.
    static func flush() {
        worker.async { send() }
    }

    private static func send() {
        guard !sending, !queue.isEmpty,
              let url = URL(string: "\(RemoteCatalog.base)/rest/v1/app_events") else { return }
        let batch = Array(queue.prefix(100))
        guard let body = try? JSONSerialization.data(withJSONObject: batch) else {
            queue.removeFirst(batch.count)
            save()
            return
        }
        sending = true
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.setValue(RemoteCatalog.key, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(RemoteCatalog.key)", forHTTPHeaderField: "Authorization")
        request.httpBody = body
        URLSession.shared.dataTask(with: request) { _, response, _ in
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            worker.async {
                sending = false
                if (200..<300).contains(status) || (400..<500).contains(status) {
                    // Sent (or refused for good: no point retrying a malformed batch).
                    queue.removeFirst(min(batch.count, queue.count))
                    save()
                    if !queue.isEmpty { send() }
                }
                // Otherwise (offline, server error): kept for the next try.
            }
        }.resume()
    }

    private static func save() {
        if let data = try? JSONSerialization.data(withJSONObject: queue) {
            UserDefaults.standard.set(data, forKey: queueKey)
        }
    }

    /// Keeps only values that can be written as JSON.
    private static func clean(_ properties: Properties) -> [String: Any] {
        var out: [String: Any] = [:]
        for (key, value) in properties {
            if let value = plain(value) { out[key] = value }
        }
        return out
    }

    private static func plain(_ value: Any) -> Any? {
        switch value {
        case let v as String: return String(v.prefix(500))
        case let v as Bool: return v
        case let v as Int: return v
        case let v as Double: return v.isFinite ? v : nil
        case let v as Float: return v.isFinite ? Double(v) : nil
        case let v as [Any]: return v.compactMap(plain)
        case let v as [String: Any]: return v.compactMapValues(plain)
        default: return String(describing: value)
        }
    }
}

// MARK: - Onboarding answers

extension UserStore.Profile {
    /// The answers given so far in the onboarding (never the first name).
    var onboardingAnswers: [String: Any] {
        var out: [String: Any] = [
            "phone_hours": phoneHours,
            "arts": arts,
            "minutes_per_day": minutes,
            "reminder_on": reminderOn,
            "reminder_minutes": reminderMinutes,
            "avatar": avatar,
            "flash_known": flashKnown,
            "flash_known_count": flashKnown.count,
            "has_first_name": !(firstName ?? "").isEmpty,
            "signed_in_apple": appleUserId != nil,
            "signed_in_google": googleUserId != nil
        ]
        if let gender { out["gender"] = gender }
        if let goals { out["goals"] = goals }
        if let goal { out["goal"] = goal }
        if let level { out["level"] = level }
        if let unknownArt { out["unknown_art"] = unknownArt }
        if let museumHabit { out["museum_habit"] = museumHabit }
        if let firstCourse { out["first_course"] = firstCourse }
        return out
    }
}
