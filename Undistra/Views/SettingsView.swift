import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @Environment(FocusStore.self) private var store

    @State private var showChangePasscode = false
    @State private var current = ""
    @State private var newCode = ""
    @State private var confirm = ""
    @State private var passcodeMessage: (text: String, isError: Bool)?
    @State private var shortcutMessage: String?
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        @Bindable var store = store

        Form {
            Section {
                HStack {
                    Label(store.hasPasscode ? "Passcode is set" : "No passcode yet",
                          systemImage: store.hasPasscode ? "checkmark.shield.fill" : "exclamationmark.shield")
                        .foregroundStyle(store.hasPasscode ? .green : .orange)
                    Spacer()
                    Button(store.hasPasscode ? "Change…" : "Set Passcode…") {
                        withAnimation { showChangePasscode.toggle() }
                    }
                }
                if showChangePasscode || !store.hasPasscode {
                    if store.hasPasscode {
                        SecureField("Current passcode", text: $current)
                    }
                    SecureField("New passcode", text: $newCode)
                    SecureField("Type it again", text: $confirm)
                    HStack {
                        if let passcodeMessage {
                            Text(passcodeMessage.text).foregroundStyle(passcodeMessage.isError ? .red : .green)
                        }
                        Spacer()
                        Button("Save Passcode", action: savePasscode)
                            .disabled(newCode.isEmpty || confirm.isEmpty)
                    }
                }
            } header: {
                Text("Passcode")
            } footer: {
                Text("Needed to open a blocked app or end a session early.")
            }

            Section {
                Toggle("Turn on Do Not Disturb during focus", isOn: $store.data.useFocusShortcuts)
                if store.data.useFocusShortcuts {
                    setupStep(1, "Open the Shortcuts app and create a shortcut called **\(store.data.focusOnShortcut)** with the action *Set Focus → Do Not Disturb → On*.")
                    setupStep(2, "Create a second shortcut called **\(store.data.focusOffShortcut)** that turns it *Off*.")
                    setupStep(3, "Press **Test** below to check it works.")
                    TextField("“On” shortcut name", text: $store.data.focusOnShortcut)
                    TextField("“Off” shortcut name", text: $store.data.focusOffShortcut)
                    HStack {
                        Button("Open Shortcuts") {
                            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Shortcuts.app"))
                        }
                        Button("Test On") { test(turnOn: true) }
                        Button("Test Off") { test(turnOn: false) }
                        if let shortcutMessage {
                            Text(shortcutMessage).font(.callout).foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("Notifications")
            } footer: {
                Text("macOS doesn't let apps mute other apps directly, so Undistra uses Shortcuts to turn Do Not Disturb on and off. Blocked apps are closed, so they can't notify you anyway.")
            }

            Section {
                Toggle("Open Undistra at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in setLaunchAtLogin(enabled) }
                Button("Show Welcome Guide Again") { store.data.hasCompletedOnboarding = false }
            } header: {
                Text("General")
            } footer: {
                Text("Recommended: schedules only work while Undistra is running.")
            }

            Section {
                Button("Apply Website Block Again") { store.syncWebsites() }
            } header: {
                Text("Troubleshooting")
            } footer: {
                Text("Use this if you cancelled the password prompt and websites aren't blocked.")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
    }

    private func setupStep(_ number: Int, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.accentColor.opacity(0.2)))
            Text(text).font(.callout)
        }
    }

    private func savePasscode() {
        do {
            try store.setPasscode(new: newCode, confirm: confirm, current: current)
            passcodeMessage = ("Passcode saved.", false)
            current = ""; newCode = ""; confirm = ""
            withAnimation { showChangePasscode = false }
        } catch {
            passcodeMessage = (error.localizedDescription, true)
        }
    }

    private func test(turnOn: Bool) {
        shortcutMessage = "Running…"
        Task { shortcutMessage = await store.testFocusShortcut(turnOn: turnOn) }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            store.lastError = "Couldn't change the login setting: \(error.localizedDescription)"
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
