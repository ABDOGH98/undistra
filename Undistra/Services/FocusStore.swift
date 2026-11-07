import AppKit
import Observation

enum PasscodeResult: Equatable {
    case success
    case wrong(remainingAttempts: Int)
    case lockedOut(until: Date)
    case notSet
}

enum PasscodeChangeError: LocalizedError {
    case wrongCurrent, tooShort, mismatch, lockedOut(Date)
    var errorDescription: String? {
        switch self {
        case .wrongCurrent: "The current passcode is wrong."
        case .tooShort: "Use at least 4 characters."
        case .mismatch: "The passcodes don't match."
        case .lockedOut(let until): "Too many wrong attempts. Try again at \(until.formatted(date: .omitted, time: .standard))."
        }
    }
}

/// Holds the app's state and decides when a focus session is running.
@MainActor
@Observable
final class FocusStore {
    static let shared = FocusStore()
    static let maxAttempts = 3
    static let lockoutDuration: TimeInterval = 60

    var data: AppData {
        didSet { persistence.save(data) }
    }
    private(set) var isFocusActive = false
    private(set) var activeUntil: Date?
    private(set) var temporaryAllowances: [String: Date] = [:]
    private(set) var hasPasscode: Bool
    private(set) var lockoutUntil: Date?
    /// The session that just ended, shown as a summary card until dismissed.
    private(set) var justFinished: FocusSessionRecord?
    var lastError: String?

    @ObservationIgnored private let persistence = Persistence()
    @ObservationIgnored private let passcode = PasscodeManager()
    @ObservationIgnored private let appBlocker = AppBlocker()
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var websiteTask: Task<Void, Never>?
    @ObservationIgnored private var failedAttempts = 0
    @ObservationIgnored private var started = false
    @ObservationIgnored private var endingEarly = false

    private init() {
        data = Persistence().load()
        hasPasscode = PasscodeManager().hasPasscode
    }

    var blockedBundleIDs: Set<String> { Set(data.blockedApps.map(\.bundleID)) }

    // MARK: Lifecycle

    func start() {
        guard !started else { return }
        started = true
        appBlocker.shouldBlock = { [weak self] app in self?.shouldBlock(app) ?? false }
        appBlocker.onBlocked = { [weak self] app in self?.presentUnlock(for: app) }
        appBlocker.start()

        evaluate()
        if !isFocusActive {
            syncWebsites() // removes a block left over from a previous run
            data.currentSessionStart = nil
        }

        let timer = Timer(timeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.evaluate() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// Works out whether focus should be on right now, and applies the change if it should.
    func evaluate(now: Date = .now) {
        let liveAllowances = temporaryAllowances.filter { $0.value > now }
        if liveAllowances.count != temporaryAllowances.count { temporaryAllowances = liveAllowances }
        if let end = data.manualSessionEnd, end <= now { data.manualSessionEnd = nil }
        if let until = data.scheduleOverrideUntil, until <= now { data.scheduleOverrideUntil = nil }

        var ends: [Date] = []
        if let end = data.manualSessionEnd { ends.append(end) }
        if data.scheduleOverrideUntil == nil {
            ends += data.schedules.compactMap { $0.currentEnd(at: now) }
        }
        let until = ends.max()
        if activeUntil != until { activeUntil = until }

        let active = until != nil
        if active != isFocusActive {
            isFocusActive = active
            active ? focusDidStart() : focusDidEnd()
        }
        if active { appBlocker.sweep() }
    }

    private func focusDidStart() {
        justFinished = nil
        if data.currentSessionStart == nil { data.currentSessionStart = .now }
        syncWebsites()
        runFocusShortcut(turnOn: true)
        appBlocker.sweep()
    }

    private func focusDidEnd() {
        recordFinishedSession()
        temporaryAllowances = [:]
        syncWebsites()
        runFocusShortcut(turnOn: false)
        UnlockPanelController.shared.close()
    }

    // MARK: Sessions

    func startSession(minutes: Int) {
        guard hasPasscode, minutes > 0 else { return }
        data.lastDurationMinutes = minutes
        let end = Date.now.addingTimeInterval(TimeInterval(minutes * 60))
        data.manualSessionEnd = max(data.manualSessionEnd ?? end, end)
        evaluate()
    }

    /// Call only after the passcode has been checked.
    func endSessionEarly() {
        if let until = activeUntil, data.schedules.contains(where: { $0.currentEnd(at: .now) != nil }) {
            data.scheduleOverrideUntil = until
        }
        data.manualSessionEnd = nil
        endingEarly = true
        evaluate()
        endingEarly = false
    }

    func dismissFinished() {
        justFinished = nil
    }

    /// 0…1, how far through the current session we are.
    func progress(at now: Date) -> Double {
        guard let start = data.currentSessionStart, let end = activeUntil, end > start else { return 0 }
        return min(1, max(0, now.timeIntervalSince(start) / end.timeIntervalSince(start)))
    }

    private func recordFinishedSession() {
        defer {
            data.currentSessionStart = nil
            data.intention = ""
        }
        guard let start = data.currentSessionStart else { return }
        let intention = data.intention.trimmingCharacters(in: .whitespacesAndNewlines)
        let record = FocusSessionRecord(start: start, end: .now, completed: !endingEarly,
                                        intention: intention.isEmpty ? nil : intention)
        guard record.duration >= 60 else { return }
        data.history.append(record)
        if data.history.count > 1000 { data.history.removeFirst(data.history.count - 1000) }
        justFinished = record
        if record.completed { NSSound(named: "Glass")?.play() }
    }

    // MARK: Stats

    var todayFocusTime: TimeInterval {
        data.history.filter { Calendar.current.isDateInToday($0.start) }.reduce(0) { $0 + $1.duration }
    }

    var todaySessionCount: Int {
        data.history.filter { Calendar.current.isDateInToday($0.start) && $0.completed }.count
    }

    /// Days in a row with at least one completed session (today counts once it has one).
    var streakDays: Int {
        let calendar = Calendar.current
        let days = Set(data.history.filter(\.completed).map { calendar.startOfDay(for: $0.start) })
        var day = calendar.startOfDay(for: .now)
        if !days.contains(day), let yesterday = calendar.date(byAdding: .day, value: -1, to: day) { day = yesterday }
        var count = 0
        while days.contains(day), let previous = calendar.date(byAdding: .day, value: -1, to: day) {
            count += 1
            day = previous
        }
        return count
    }

    func completeOnboarding() {
        data.hasCompletedOnboarding = true
    }

    // MARK: Passcode

    func verifyPasscode(_ code: String) -> PasscodeResult {
        guard hasPasscode else { return .notSet }
        if let until = lockoutUntil, until > .now { return .lockedOut(until: until) }
        if passcode.verify(code) {
            failedAttempts = 0
            lockoutUntil = nil
            return .success
        }
        failedAttempts += 1
        if failedAttempts >= Self.maxAttempts {
            failedAttempts = 0
            let until = Date.now.addingTimeInterval(Self.lockoutDuration)
            lockoutUntil = until
            return .lockedOut(until: until)
        }
        return .wrong(remainingAttempts: Self.maxAttempts - failedAttempts)
    }

    func setPasscode(new: String, confirm: String, current: String?) throws {
        if hasPasscode {
            switch verifyPasscode(current ?? "") {
            case .success: break
            case .lockedOut(let until): throw PasscodeChangeError.lockedOut(until)
            default: throw PasscodeChangeError.wrongCurrent
            }
        }
        guard new.count >= 4 else { throw PasscodeChangeError.tooShort }
        guard new == confirm else { throw PasscodeChangeError.mismatch }
        try passcode.save(new)
        hasPasscode = true
    }

    // MARK: App blocking

    private func shouldBlock(_ app: NSRunningApplication) -> Bool {
        guard isFocusActive,
              let id = app.bundleIdentifier,
              id != Bundle.main.bundleIdentifier,
              blockedBundleIDs.contains(id) else { return false }
        if let until = temporaryAllowances[id], until > .now { return false }
        return true
    }

    private func presentUnlock(for app: NSRunningApplication) {
        guard let id = app.bundleIdentifier else { return }
        let name = app.localizedName ?? data.blockedApps.first { $0.bundleID == id }?.name ?? "This app"
        let request = UnlockRequest(appName: name, bundleID: id, appURL: app.bundleURL)
        UnlockPanelController.shared.show(request, store: self)
    }

    /// Call only after the passcode has been checked.
    func grantTemporaryAccess(_ request: UnlockRequest, minutes: Int) {
        temporaryAllowances[request.bundleID] = Date.now.addingTimeInterval(TimeInterval(minutes * 60))
        guard let url = request.appURL else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { _, _ in }
    }

    func addApp(at url: URL) {
        guard let app = AppCatalog.app(at: url) else {
            lastError = "\(url.lastPathComponent) doesn't look like an app."
            return
        }
        addApp(app)
    }

    func addApp(_ app: BlockedApp) {
        guard AppCatalog.canBlock(app.bundleID), !blockedBundleIDs.contains(app.bundleID) else { return }
        data.blockedApps.append(app)
        data.blockedApps.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        if isFocusActive { appBlocker.sweep() }
    }

    /// Lists can only get stricter during a session: removing is disabled until it ends.
    func removeApp(_ app: BlockedApp) {
        guard !isFocusActive else { return }
        data.blockedApps.removeAll { $0.bundleID == app.bundleID }
    }

    // MARK: Website blocking

    @discardableResult
    func addWebsite(_ input: String) -> Bool {
        guard let domain = BlockedWebsite.normalize(input) else { return false }
        guard !data.blockedWebsites.contains(where: { $0.domain == domain }) else { return true }
        data.blockedWebsites.append(BlockedWebsite(domain: domain))
        data.blockedWebsites.sort { $0.domain < $1.domain }
        if isFocusActive { syncWebsites() }
        return true
    }

    func removeWebsite(_ site: BlockedWebsite) {
        guard !isFocusActive else { return }
        data.blockedWebsites.removeAll { $0.domain == site.domain }
    }

    func isWebsiteBlocked(_ domain: String) -> Bool {
        data.blockedWebsites.contains { $0.domain == domain }
    }

    func isCategoryBlocked(_ category: WebsiteCategory) -> Bool {
        category.domains.allSatisfy(isWebsiteBlocked)
    }

    /// Adds or removes a whole category. Removing is ignored during a session.
    func setCategory(_ category: WebsiteCategory, blocked: Bool) {
        if blocked {
            let new = category.domains.filter { !isWebsiteBlocked($0) }.map(BlockedWebsite.init(domain:))
            guard !new.isEmpty else { return }
            data.blockedWebsites = (data.blockedWebsites + new).sorted { $0.domain < $1.domain }
            if isFocusActive { syncWebsites() }
        } else {
            guard !isFocusActive else { return }
            data.blockedWebsites.removeAll { category.domains.contains($0.domain) }
        }
    }

    /// Updates /etc/hosts to match the current state. Updates run one at a time, in order.
    func syncWebsites() {
        let domains = isFocusActive ? data.blockedWebsites.map(\.domain) : []
        let previous = websiteTask
        websiteTask = Task { [weak self] in
            await previous?.value
            do {
                try await WebsiteBlocker.shared.apply(domains: domains)
            } catch {
                self?.lastError = error.localizedDescription
            }
        }
    }

    // MARK: Schedules

    func saveSchedule(_ schedule: FocusSchedule) {
        if let index = data.schedules.firstIndex(where: { $0.id == schedule.id }) {
            guard !isFocusActive else { return }
            data.schedules[index] = schedule
        } else {
            data.schedules.append(schedule)
        }
        evaluate()
    }

    func deleteSchedule(_ schedule: FocusSchedule) {
        guard !isFocusActive else { return }
        data.schedules.removeAll { $0.id == schedule.id }
        evaluate()
    }

    func setSchedule(_ schedule: FocusSchedule, enabled: Bool) {
        guard enabled || !isFocusActive,
              let index = data.schedules.firstIndex(where: { $0.id == schedule.id }) else { return }
        data.schedules[index].isEnabled = enabled
        evaluate()
    }

    // MARK: Focus mode (notifications)

    private func runFocusShortcut(turnOn: Bool) {
        guard data.useFocusShortcuts else { return }
        let name = turnOn ? data.focusOnShortcut : data.focusOffShortcut
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        Task { [weak self] in
            do { try await FocusModeController.run(shortcut: name) } catch { self?.lastError = error.localizedDescription }
        }
    }

    func testFocusShortcut(turnOn: Bool) async -> String {
        let name = turnOn ? data.focusOnShortcut : data.focusOffShortcut
        do {
            try await FocusModeController.run(shortcut: name)
            return "\"\(name)\" ran."
        } catch {
            return error.localizedDescription
        }
    }
}
