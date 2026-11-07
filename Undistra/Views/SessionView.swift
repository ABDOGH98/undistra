import SwiftUI

struct SessionView: View {
    @Environment(FocusStore.self) private var store
    let onEditBlockList: () -> Void

    @State private var minutes = 50
    @State private var customMinutes = false
    @State private var confirmEnd = false

    private let presets = [25, 50, 90]

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 20)
            if store.isFocusActive {
                ActiveSession(confirmEnd: $confirmEnd)
            } else if let finished = store.justFinished {
                FinishedCard(record: finished)
            } else {
                idleContent
            }
            Spacer(minLength: 20)
            TodayStats().padding(.bottom, 4)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Focus")
        .onAppear {
            minutes = store.data.lastDurationMinutes
            customMinutes = !presets.contains(minutes)
        }
        .sheet(isPresented: $confirmEnd) {
            PasscodeSheet(title: "End this session early?",
                          message: "Your blocked apps and websites will open again. You can always start a new session later.",
                          confirmTitle: "End Session") {
                store.endSessionEarly()
            }
        }
    }

    // MARK: Idle

    private var idleContent: some View {
        @Bindable var store = store
        let nothingBlocked = store.data.blockedApps.isEmpty && store.data.blockedWebsites.isEmpty

        return VStack(spacing: 22) {
            Text("Ready to focus?")
                .font(.system(size: 34, weight: .bold, design: .rounded))

            // Writing down the task makes people more likely to stick with it.
            VStack(spacing: 6) {
                TextField("What will you work on?", text: $store.data.intention, prompt: Text("What will you work on? (optional)"))
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 10).padding(.horizontal, 14)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.separator))
                    .frame(maxWidth: 440)
                    .onSubmit(start)
            }

            durationPicker

            VStack(spacing: 8) {
                Button(action: start) {
                    Label("Start \(TimeFormat.minutes(minutes)) focus", systemImage: "play.fill")
                        .font(.headline)
                        .frame(minWidth: 240)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .disabled(!store.hasPasscode)

                TimelineView(.everyMinute) { context in
                    Text("Ends at \(TimeFormat.time(context.date.addingTimeInterval(TimeInterval(minutes * 60))))")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            whatGetsBlocked(nothingBlocked: nothingBlocked)
        }
    }

    private var durationPicker: some View {
        HStack(spacing: 8) {
            ForEach(presets, id: \.self) { preset in
                durationChip(TimeFormat.minutes(preset), selected: !customMinutes && minutes == preset) {
                    customMinutes = false
                    minutes = preset
                }
            }
            durationChip("Custom", selected: customMinutes) { customMinutes = true }
            if customMinutes {
                Stepper(value: $minutes, in: 5...480, step: 5) {
                    Text(TimeFormat.minutes(minutes)).monospacedDigit().frame(minWidth: 80)
                }
                .fixedSize()
            }
        }
    }

    private func durationChip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.callout.weight(selected ? .semibold : .regular))
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(Capsule().fill(selected ? Color.accentColor : Color(nsColor: .controlBackgroundColor)))
                .foregroundStyle(selected ? .white : .primary)
                .overlay(Capsule().strokeBorder(selected ? .clear : Color(nsColor: .separatorColor)))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func whatGetsBlocked(nothingBlocked: Bool) -> some View {
        if !store.hasPasscode {
            Label("Set a passcode in Settings to start.", systemImage: "key.fill")
                .foregroundStyle(.orange)
        } else if nothingBlocked {
            HStack(spacing: 8) {
                Label("Nothing is blocked yet.", systemImage: "exclamationmark.circle")
                    .foregroundStyle(.orange)
                Button("Choose distractions", action: onEditBlockList).buttonStyle(.link)
            }
        } else {
            VStack(spacing: 6) {
                HStack(spacing: 10) {
                    Text("Will block").font(.callout).foregroundStyle(.secondary)
                    BlockPreview()
                    Button("Edit", action: onEditBlockList).buttonStyle(.link)
                }
                if !store.data.blockedWebsites.isEmpty {
                    Text("macOS will ask for your password to block websites.")
                        .font(.caption).foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func start() {
        guard store.hasPasscode else { return }
        store.startSession(minutes: minutes)
    }
}

// MARK: - Active session

private struct ActiveSession: View {
    @Environment(FocusStore.self) private var store
    @Binding var confirmEnd: Bool

    var body: some View {
        VStack(spacing: 22) {
            if let until = store.activeUntil {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    ZStack {
                        FocusRing(progress: store.progress(at: context.date))
                        VStack(spacing: 4) {
                            Text(TimeFormat.countdown(until.timeIntervalSince(context.date)))
                                .font(.system(size: 54, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                            Text("until \(TimeFormat.time(until))")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 260, height: 260)
                }
            }

            VStack(spacing: 6) {
                if !store.data.intention.isEmpty {
                    Text("Working on").font(.callout).foregroundStyle(.secondary)
                    Text(store.data.intention)
                        .font(.title2.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 460)
                } else {
                    Text("You're in focus mode").font(.title2.weight(.semibold))
                }
            }

            HStack(spacing: 10) {
                Image(systemName: "lock.fill").foregroundStyle(.tint)
                BlockPreview()
            }

            // Kept small on purpose: ending early is allowed, but shouldn't be the obvious next step.
            Button("End early…") { confirmEnd = true }
                .buttonStyle(.link)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
    }
}

// MARK: - Finished

/// Shown when a session ends. A good ending makes the whole session feel worth it.
private struct FinishedCard: View {
    @Environment(FocusStore.self) private var store
    let record: FocusSessionRecord

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: record.completed ? "checkmark.seal.fill" : "pause.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(record.completed ? AnyShapeStyle(.green) : AnyShapeStyle(.secondary))
                .symbolEffect(.bounce, value: record.id)

            Text(record.completed ? "Session complete" : "Session ended")
                .font(.system(size: 30, weight: .bold, design: .rounded))

            Group {
                if let intention = record.intention {
                    Text("You focused for **\(TimeFormat.duration(record.duration))** on “\(intention)”.")
                } else {
                    Text("You focused for **\(TimeFormat.duration(record.duration))**.")
                }
            }
            .font(.title3)
            .multilineTextAlignment(.center)

            if !record.completed {
                Text("That still counts. Start again whenever you're ready.")
                    .foregroundStyle(.secondary)
            } else if store.streakDays > 1 {
                Label("\(store.streakDays)-day streak. Keep it going!", systemImage: "flame.fill")
                    .foregroundStyle(.orange)
            }

            HStack(spacing: 12) {
                Button("Take a Break") { store.dismissFinished() }
                    .controlSize(.large)
                Button("Start Another Session") {
                    store.dismissFinished()
                    store.startSession(minutes: store.data.lastDurationMinutes)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 6)
        }
    }
}
