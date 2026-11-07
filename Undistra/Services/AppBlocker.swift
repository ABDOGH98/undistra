import AppKit

/// Watches app launches/activations and closes apps that `shouldBlock` says are blocked.
@MainActor
final class AppBlocker {
    var shouldBlock: (NSRunningApplication) -> Bool = { _ in false }
    var onBlocked: (NSRunningApplication) -> Void = { _ in }

    private var observers: [NSObjectProtocol] = []
    private var terminating: Set<pid_t> = []

    func start() {
        guard observers.isEmpty else { return }
        let center = NSWorkspace.shared.notificationCenter
        let names = [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didActivateApplicationNotification]
        for name in names {
            let observer = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
                MainActor.assumeIsolated {
                    self?.handle(app, showPrompt: true)
                }
            }
            observers.append(observer)
        }
    }

    /// Closes every blocked app that is already running (on session start, or when a temporary unlock ends).
    func sweep() {
        for app in NSWorkspace.shared.runningApplications {
            handle(app, showPrompt: false)
        }
    }

    private func handle(_ app: NSRunningApplication, showPrompt: Bool) {
        guard !app.isTerminated, shouldBlock(app) else { return }
        block(app, showPrompt: showPrompt)
    }

    private func block(_ app: NSRunningApplication, showPrompt: Bool) {
        let pid = app.processIdentifier
        guard !terminating.contains(pid) else { return }
        terminating.insert(pid)

        app.hide()
        app.terminate()
        // Apps can delay quitting (e.g. a "save changes?" dialog). Force them after a few seconds.
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            if !app.isTerminated { app.forceTerminate() }
            self?.terminating.remove(pid)
        }
        if showPrompt { onBlocked(app) }
    }
}
