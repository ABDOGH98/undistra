import SwiftUI

// MARK: - Basics

struct AppIconView: View {
    let path: String?
    var size: CGFloat = 28

    var body: some View {
        Group {
            if let path, FileManager.default.fileExists(atPath: path) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: path)).resizable()
            } else {
                Image(systemName: "app.dashed").resizable().foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
    }
}

struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            Text(message).font(.callout).textSelection(.enabled)
            Spacer()
            Button("Dismiss", action: onDismiss).buttonStyle(.borderless)
        }
        .padding(12)
        .background(.orange.opacity(0.1))
    }
}

/// Explains why removing is disabled, instead of leaving people wondering why buttons are greyed out.
struct LockedNotice: View {
    var body: some View {
        Label("Focus is on. You can still add things, but removing them waits until the session ends.",
              systemImage: "lock.fill")
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct SectionHeader: View {
    let title: String
    var subtitle: String?
    var count: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(title).font(.headline)
                if let count {
                    Text("\(count)")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(.quaternary, in: Capsule())
                }
            }
            if let subtitle {
                Text(subtitle).font(.callout).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Progress

/// Ring that fills as the session goes on. Seeing progress makes it easier to keep going.
struct FocusRing: View {
    let progress: Double
    var lineWidth: CGFloat = 14

    var body: some View {
        ZStack {
            Circle().stroke(.quaternary, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.002, min(progress, 1)))
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: progress)
        }
    }
}

/// Today's focus time, completed sessions and day streak.
struct TodayStats: View {
    @Environment(FocusStore.self) private var store
    var compact = false

    var body: some View {
        HStack(spacing: compact ? 14 : 32) {
            stat(TimeFormat.duration(store.todayFocusTime), "focused today", "clock.fill")
            stat("\(store.todaySessionCount)", store.todaySessionCount == 1 ? "session" : "sessions", "checkmark.circle.fill")
            stat("\(store.streakDays)", store.streakDays == 1 ? "day streak" : "day streak", "flame.fill")
        }
    }

    private func stat(_ value: String, _ label: String, _ icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(.tint)
            Text(value).fontWeight(.semibold).monospacedDigit()
            Text(label).foregroundStyle(.secondary)
        }
        .font(compact ? .caption : .callout)
    }
}

// MARK: - Picking things to block

/// One app as a tappable tile. Used for both "blocked" (tap ✕ to remove) and "suggested" (tap + to add).
struct AppTile: View {
    let app: BlockedApp
    let isBlocked: Bool
    var disabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                AppIconView(path: app.path, size: 24)
                Text(app.name).lineLimit(1)
                Spacer(minLength: 4)
                Image(systemName: isBlocked ? "xmark.circle.fill" : "plus.circle.fill")
                    .foregroundStyle(isBlocked ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.tint))
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isBlocked ? Color.accentColor.opacity(0.12) : Color(nsColor: .controlBackgroundColor))
            )
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .help(isBlocked ? "Stop blocking \(app.name)" : "Block \(app.name)")
    }
}

/// A website as a small capsule.
struct WebsiteChip: View {
    let domain: String
    let isBlocked: Bool
    var disabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(domain).lineLimit(1)
                Image(systemName: isBlocked ? "xmark" : "plus").font(.caption2.weight(.bold))
            }
            .font(.callout)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Capsule().fill(isBlocked ? Color.accentColor.opacity(0.15) : Color(nsColor: .controlBackgroundColor)))
            .overlay(Capsule().strokeBorder(.separator))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}

/// A whole website category as one on/off card.
struct CategoryCard: View {
    @Environment(FocusStore.self) private var store
    let category: WebsiteCategory

    var body: some View {
        let isOn = store.isCategoryBlocked(category)
        Button {
            store.setCategory(category, blocked: !isOn)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: category.icon)
                    .font(.title3)
                    .frame(width: 28)
                    .foregroundStyle(isOn ? AnyShapeStyle(.white) : AnyShapeStyle(.tint))
                VStack(alignment: .leading, spacing: 2) {
                    Text(category.name).fontWeight(.medium)
                    Text(category.domains.prefix(3).joined(separator: ", ") + "…")
                        .font(.caption)
                        .foregroundStyle(isOn ? AnyShapeStyle(.white.opacity(0.8)) : AnyShapeStyle(.secondary))
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isOn ? AnyShapeStyle(.white) : AnyShapeStyle(.tertiary))
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10).fill(isOn ? Color.accentColor : Color(nsColor: .controlBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.separator))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isOn && store.isFocusActive)
    }
}

/// Grid of app suggestions: apps open right now first, then common distractions.
struct AppSuggestions: View {
    @Environment(FocusStore.self) private var store
    @State private var open: [BlockedApp] = []
    @State private var common: [BlockedApp] = []

    private let columns = [GridItem(.adaptive(minimum: 170), spacing: 8)]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            group("Open right now", open)
            group("Often distracting", common)
            if open.isEmpty && common.isEmpty {
                Text("No suggestions. Use “Choose Another App…” to pick any app.")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
        .onAppear(perform: refresh)
        .onChange(of: store.data.blockedApps) { refresh() }
    }

    @ViewBuilder
    private func group(_ title: String, _ apps: [BlockedApp]) -> some View {
        if !apps.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.subheadline).foregroundStyle(.secondary)
                LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                    ForEach(apps) { app in
                        AppTile(app: app, isBlocked: false) { store.addApp(app) }
                    }
                }
            }
        }
    }

    private func refresh() {
        let result = AppCatalog.suggestions(excluding: store.blockedBundleIDs)
        open = result.open
        common = result.common
    }
}

/// Small row of icons previewing what a session will block.
struct BlockPreview: View {
    @Environment(FocusStore.self) private var store

    var body: some View {
        let apps = store.data.blockedApps
        HStack(spacing: 6) {
            ForEach(apps.prefix(6)) { app in
                AppIconView(path: app.path, size: 22).help(app.name)
            }
            if apps.count > 6 {
                Text("+\(apps.count - 6)").font(.caption).foregroundStyle(.secondary)
            }
            if !store.data.blockedWebsites.isEmpty {
                if !apps.isEmpty { Text("·").foregroundStyle(.tertiary) }
                Image(systemName: "globe").foregroundStyle(.secondary)
                Text("\(store.data.blockedWebsites.count) websites").font(.callout).foregroundStyle(.secondary)
            }
        }
    }
}

@MainActor
func pickOtherApps(into store: FocusStore) {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.application]
    panel.allowsMultipleSelection = true
    panel.canChooseDirectories = false
    panel.directoryURL = URL(fileURLWithPath: "/Applications")
    panel.prompt = "Block"
    panel.message = "Choose apps to block during focus"
    if panel.runModal() == .OK {
        for url in panel.urls { store.addApp(at: url) }
    }
}

// MARK: - Passcode sheet

/// Asks for the passcode before a protected action, such as ending a session.
struct PasscodeSheet: View {
    @Environment(FocusStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let title: String
    let message: String
    let confirmTitle: String
    let onSuccess: () -> Void

    @State private var code = ""
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.title3.bold())
            Text(message).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            SecureField("Passcode", text: $code)
                .textFieldStyle(.roundedBorder)
                .onSubmit(submit)
            if let error { Text(error).foregroundStyle(.red).font(.callout) }
            HStack {
                Spacer()
                Button("Keep Going") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(confirmTitle, action: submit)
                    .disabled(code.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 400)
    }

    private func submit() {
        if let message = passcodeErrorMessage(store.verifyPasscode(code)) {
            error = message
        } else {
            dismiss()
            onSuccess()
        }
        code = ""
    }
}

/// nil means success.
func passcodeErrorMessage(_ result: PasscodeResult) -> String? {
    switch result {
    case .success: nil
    case .wrong(let remaining): "Wrong passcode. \(remaining) attempt\(remaining == 1 ? "" : "s") left."
    case .lockedOut(let until): "Too many tries. Wait until \(until.formatted(date: .omitted, time: .standard))."
    case .notSet: "No passcode is set yet."
    }
}
