import Foundation

struct BlockedApp: Identifiable, Codable, Hashable {
    var id: String { bundleID }
    let bundleID: String
    var name: String
    var path: String?
}

struct BlockedWebsite: Identifiable, Codable, Hashable {
    var id: String { domain }
    let domain: String

    /// Turns "https://www.YouTube.com/watch?v=1" into "youtube.com".
    static func normalize(_ input: String) -> String? {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !text.isEmpty else { return nil }
        if !text.contains("://") { text = "https://" + text }
        guard var host = URL(string: text)?.host(), host.contains(".") else { return nil }
        for prefix in ["www.", "m."] where host.hasPrefix(prefix) {
            host.removeFirst(prefix.count)
        }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789.-")
        guard host.unicodeScalars.allSatisfy(allowed.contains), !host.hasPrefix("."), !host.hasSuffix(".") else {
            return nil
        }
        return host
    }
}

/// Website groups. Picking a category is one decision instead of ten.
struct WebsiteCategory: Identifiable, Hashable {
    let name: String
    let icon: String
    let domains: [String]
    var id: String { name }

    static let all = [
        WebsiteCategory(name: "Social media", icon: "person.2.fill",
                        domains: ["facebook.com", "instagram.com", "x.com", "twitter.com", "tiktok.com",
                                  "reddit.com", "snapchat.com", "threads.net", "linkedin.com"]),
        WebsiteCategory(name: "Video & streaming", icon: "play.rectangle.fill",
                        domains: ["youtube.com", "youtu.be", "netflix.com", "twitch.tv", "primevideo.com", "disneyplus.com"]),
        WebsiteCategory(name: "News", icon: "newspaper.fill",
                        domains: ["news.ycombinator.com", "cnn.com", "bbc.com", "nytimes.com", "theguardian.com"]),
        WebsiteCategory(name: "Shopping", icon: "cart.fill",
                        domains: ["amazon.com", "ebay.com", "aliexpress.com", "temu.com"]),
    ]
}

struct FocusSchedule: Identifiable, Codable, Hashable {
    var id = UUID()
    var name = "Deep work"
    /// Calendar weekdays: 1 = Sunday … 7 = Saturday.
    var weekdays: Set<Int> = [2, 3, 4, 5, 6]
    /// Minutes after midnight.
    var startMinutes = 9 * 60
    var endMinutes = 12 * 60
    var isEnabled = true

    /// Ready-made schedules, so you start from a sensible default instead of a blank form.
    static let presets: [FocusSchedule] = [
        FocusSchedule(name: "Weekday mornings", weekdays: [2, 3, 4, 5, 6], startMinutes: 9 * 60, endMinutes: 12 * 60),
        FocusSchedule(name: "Weekday afternoons", weekdays: [2, 3, 4, 5, 6], startMinutes: 14 * 60, endMinutes: 17 * 60),
        FocusSchedule(name: "Full workday", weekdays: [2, 3, 4, 5, 6], startMinutes: 9 * 60, endMinutes: 17 * 60),
        FocusSchedule(name: "Screen-free nights", weekdays: Set(1...7), startMinutes: 22 * 60, endMinutes: 7 * 60),
    ]

    /// A copy with a new id, so a preset can be added more than once.
    func copy() -> FocusSchedule {
        var s = self
        s.id = UUID()
        return s
    }

    /// When the occurrence containing `date` ends, or nil if the schedule isn't active at `date`.
    /// Handles overnight ranges such as 22:00 → 06:00.
    func currentEnd(at date: Date, calendar: Calendar = .current) -> Date? {
        guard isEnabled, startMinutes != endMinutes else { return nil }
        let parts = calendar.dateComponents([.weekday, .hour, .minute], from: date)
        let minute = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        let weekday = parts.weekday ?? 1
        let startOfDay = calendar.startOfDay(for: date)

        if startMinutes < endMinutes {
            guard weekdays.contains(weekday), minute >= startMinutes, minute < endMinutes else { return nil }
            return calendar.date(byAdding: .minute, value: endMinutes, to: startOfDay)
        }
        if weekdays.contains(weekday), minute >= startMinutes,
           let tomorrow = calendar.date(byAdding: .day, value: 1, to: startOfDay) {
            return calendar.date(byAdding: .minute, value: endMinutes, to: tomorrow)
        }
        let previousDay = weekday == 1 ? 7 : weekday - 1
        if weekdays.contains(previousDay), minute < endMinutes {
            return calendar.date(byAdding: .minute, value: endMinutes, to: startOfDay)
        }
        return nil
    }

    /// The next time this schedule starts after `date`.
    func nextStart(after date: Date, calendar: Calendar = .current) -> Date? {
        guard isEnabled, !weekdays.isEmpty, startMinutes != endMinutes else { return nil }
        let today = calendar.startOfDay(for: date)
        for offset in 0...7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  weekdays.contains(calendar.component(.weekday, from: day)),
                  let start = calendar.date(byAdding: .minute, value: startMinutes, to: day),
                  start > date else { continue }
            return start
        }
        return nil
    }

    var timeRangeText: String {
        "\(Self.format(startMinutes)) – \(Self.format(endMinutes))"
    }

    var weekdaysText: String {
        let symbols = Calendar.current.shortWeekdaySymbols
        if weekdays.count == 7 { return "Every day" }
        if weekdays == [2, 3, 4, 5, 6] { return "Mon – Fri" }
        if weekdays == [1, 7] { return "Weekends" }
        return Calendar.current.orderedWeekdays
            .filter(weekdays.contains)
            .map { symbols[$0 - 1] }
            .joined(separator: ", ")
    }

    static func format(_ minutes: Int) -> String {
        let date = Calendar.current.date(byAdding: .minute, value: minutes, to: Calendar.current.startOfDay(for: .now)) ?? .now
        return date.formatted(date: .omitted, time: .shortened)
    }
}

extension Calendar {
    /// Weekday numbers ordered by the user's first day of the week.
    var orderedWeekdays: [Int] {
        (0..<7).map { (firstWeekday - 1 + $0) % 7 + 1 }
    }
}

/// One finished focus session, kept for stats and streaks.
struct FocusSessionRecord: Identifiable, Codable, Hashable {
    var id = UUID()
    let start: Date
    let end: Date
    let completed: Bool
    var intention: String?

    var duration: TimeInterval { end.timeIntervalSince(start) }
}

/// Everything Undistra saves to disk.
struct AppData: Codable {
    var blockedApps: [BlockedApp] = []
    var blockedWebsites: [BlockedWebsite] = []
    var schedules: [FocusSchedule] = []
    var manualSessionEnd: Date?
    /// Set when a session is ended early during a schedule, so the schedule doesn't restart it.
    var scheduleOverrideUntil: Date?
    var useFocusShortcuts = false
    var focusOnShortcut = "Undistra On"
    var focusOffShortcut = "Undistra Off"
    var hasCompletedOnboarding = false
    /// What the user said they'd work on in the current session.
    var intention = ""
    var currentSessionStart: Date?
    var lastDurationMinutes = 50
    var history: [FocusSessionRecord] = []

    init() {}

    // Missing keys fall back to defaults, so adding fields later never breaks saved data.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppData()
        blockedApps = try c.decodeIfPresent([BlockedApp].self, forKey: .blockedApps) ?? d.blockedApps
        blockedWebsites = try c.decodeIfPresent([BlockedWebsite].self, forKey: .blockedWebsites) ?? d.blockedWebsites
        schedules = try c.decodeIfPresent([FocusSchedule].self, forKey: .schedules) ?? d.schedules
        manualSessionEnd = try c.decodeIfPresent(Date.self, forKey: .manualSessionEnd)
        scheduleOverrideUntil = try c.decodeIfPresent(Date.self, forKey: .scheduleOverrideUntil)
        useFocusShortcuts = try c.decodeIfPresent(Bool.self, forKey: .useFocusShortcuts) ?? d.useFocusShortcuts
        focusOnShortcut = try c.decodeIfPresent(String.self, forKey: .focusOnShortcut) ?? d.focusOnShortcut
        focusOffShortcut = try c.decodeIfPresent(String.self, forKey: .focusOffShortcut) ?? d.focusOffShortcut
        hasCompletedOnboarding = try c.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? d.hasCompletedOnboarding
        intention = try c.decodeIfPresent(String.self, forKey: .intention) ?? d.intention
        currentSessionStart = try c.decodeIfPresent(Date.self, forKey: .currentSessionStart)
        lastDurationMinutes = try c.decodeIfPresent(Int.self, forKey: .lastDurationMinutes) ?? d.lastDurationMinutes
        history = try c.decodeIfPresent([FocusSessionRecord].self, forKey: .history) ?? d.history
    }
}

enum TimeFormat {
    /// "24:59" or "1:05:00"
    static func countdown(_ interval: TimeInterval) -> String {
        let s = max(0, Int(interval.rounded(.up)))
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%02d:%02d", m, sec)
    }

    /// "1h 40m", "25m"
    static func duration(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval / 60))
        let h = total / 60, m = total % 60
        if h == 0 { return "\(m)m" }
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }

    /// "50 min", "1 h 30 min"
    static func minutes(_ minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        if h == 0 { return "\(m) min" }
        return m == 0 ? "\(h) h" : "\(h) h \(m) min"
    }

    static func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}
