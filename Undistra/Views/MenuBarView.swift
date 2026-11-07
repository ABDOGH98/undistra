import SwiftUI

struct MenuBarView: View {
    @Environment(FocusStore.self) private var store
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if store.isFocusActive, let until = store.activeUntil {
                active(until: until)
            } else {
                idle
            }

            Divider()

            HStack {
                Button("Open Undistra") {
                    openWindow(id: "main")
                    NSApp.activate()
                }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
        }
        .padding(14)
        .frame(width: 270)
    }

    private func active(until: Date) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            HStack(spacing: 14) {
                ZStack {
                    FocusRing(progress: store.progress(at: context.date), lineWidth: 6)
                    Image(systemName: "lock.fill").foregroundStyle(.tint)
                }
                .frame(width: 52, height: 52)
                VStack(alignment: .leading, spacing: 2) {
                    Text(TimeFormat.countdown(until.timeIntervalSince(context.date)))
                        .font(.system(size: 26, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text(store.data.intention.isEmpty ? "until \(TimeFormat.time(until))" : store.data.intention)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
    }

    private var idle: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Start focusing").font(.headline)
            if store.hasPasscode {
                HStack(spacing: 6) {
                    ForEach([25, 50, 90], id: \.self) { minutes in
                        Button("\(minutes) min") { store.startSession(minutes: minutes) }
                            .buttonStyle(.bordered)
                            .help("Ends at \(TimeFormat.time(.now.addingTimeInterval(TimeInterval(minutes * 60))))")
                    }
                }
            } else {
                Button("Finish setup…") {
                    openWindow(id: "main")
                    NSApp.activate()
                }
            }
            TodayStats(compact: true)
        }
    }
}
