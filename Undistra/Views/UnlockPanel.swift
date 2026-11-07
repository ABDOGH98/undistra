import AppKit
import SwiftUI

struct UnlockRequest: Equatable {
    let appName: String
    let bundleID: String
    let appURL: URL?
}

/// Floating window that appears when you try to open a blocked app.
@MainActor
final class UnlockPanelController {
    static let shared = UnlockPanelController()
    private var panel: NSPanel?

    func show(_ request: UnlockRequest, store: FocusStore) {
        let view = UnlockView(request: request) { [weak self] in self?.close() }
            .environment(store)
        let hosting = NSHostingController(rootView: view)
        hosting.sizingOptions = .preferredContentSize
        let panel = self.panel ?? makePanel()
        panel.contentViewController = hosting
        panel.center()
        self.panel = panel
        // Wait a moment so the blocked app's launch doesn't take focus back.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NSApp.activate()
            panel.makeKeyAndOrderFront(nil)
        }
    }

    func close() {
        panel?.orderOut(nil)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 400, height: 360),
                            styleMask: [.titled, .closable, .fullSizeContentView],
                            backing: .buffered, defer: false)
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        return panel
    }
}

/// Staying focused is the big, default choice. Unlocking is still possible,
/// but sits behind one extra click, so it's a deliberate decision and not a reflex.
struct UnlockView: View {
    @Environment(FocusStore.self) private var store
    let request: UnlockRequest
    let onClose: () -> Void

    @State private var showUnlock = false
    @State private var code = ""
    @State private var minutes = 5
    @State private var message: String?

    var body: some View {
        VStack(spacing: 18) {
            ZStack(alignment: .bottomTrailing) {
                AppIconView(path: request.appURL?.path, size: 60).opacity(0.85)
                Image(systemName: "lock.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.white, Color.accentColor)
                    .offset(x: 6, y: 6)
            }
            .padding(.top, 8)

            VStack(spacing: 6) {
                Text("\(request.appName) is blocked right now")
                    .font(.title3.bold())
                    .multilineTextAlignment(.center)
                if !store.data.intention.isEmpty {
                    Text("You're working on “\(store.data.intention)”.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            if let until = store.activeUntil {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    VStack(spacing: 6) {
                        ProgressView(value: store.progress(at: context.date))
                        Text("\(TimeFormat.duration(until.timeIntervalSince(context.date) + 59)) left · ends at \(TimeFormat.time(until))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            Button {
                onClose()
            } label: {
                Text("Stay Focused").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.cancelAction)

            if showUnlock {
                unlockForm
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                Button("I really need it…") {
                    withAnimation(.snappy) { showUnlock = true }
                }
                .buttonStyle(.link)
                .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .frame(width: 380)
    }

    private var unlockForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()
            Text("Open \(request.appName) for")
                .font(.callout).foregroundStyle(.secondary)
            Picker("Open for", selection: $minutes) {
                ForEach([5, 10, 15, 30], id: \.self) { Text("\($0) min").tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            HStack {
                SecureField("Passcode", text: $code)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(unlock)
                Button("Open", action: unlock).disabled(code.isEmpty)
            }
            if let message {
                Text(message).font(.callout).foregroundStyle(.red)
            }
            Text("It will close again automatically after \(minutes) minutes.")
                .font(.caption).foregroundStyle(.tertiary)
        }
    }

    private func unlock() {
        if let error = passcodeErrorMessage(store.verifyPasscode(code)) {
            message = error
        } else {
            store.grantTemporaryAccess(request, minutes: minutes)
            onClose()
        }
        code = ""
    }
}
