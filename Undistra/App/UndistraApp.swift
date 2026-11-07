import SwiftUI

@main
struct UndistraApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = FocusStore.shared

    var body: some Scene {
        Window("Undistra", id: "main") {
            ContentView()
                .environment(store)
                .frame(minWidth: 780, minHeight: 520)
        }
        .windowResizability(.contentMinSize)

        MenuBarExtra {
            MenuBarView()
                .environment(store)
        } label: {
            Image(store.isFocusActive ? "MenuBarIconOn" : "MenuBarIconOff")
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        FocusStore.shared.start()
    }

    /// Keep running in the menu bar when the window is closed, so blocking keeps working.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// Quitting would stop app blocking, so it isn't allowed during a session.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard FocusStore.shared.isFocusActive else { return .terminateNow }
        let alert = NSAlert()
        alert.messageText = "A focus session is running"
        alert.informativeText = "End the session first (this needs your passcode), then quit Undistra."
        alert.addButton(withTitle: "Stay focused")
        NSApp.activate()
        alert.runModal()
        return .terminateCancel
    }
}
