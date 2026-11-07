import SwiftUI

struct SchedulesView: View {
    @Environment(FocusStore.self) private var store
    @State private var editing: FocusSchedule?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SectionHeader(title: "Automatic focus",
                              subtitle: "Focus starts and stops by itself at these times. Undistra needs to be running (turn on “Open at login” in Settings).")

                if store.isFocusActive { LockedNotice() }

                if !store.data.schedules.isEmpty {
                    TimelineView(.everyMinute) { context in
                        VStack(spacing: 8) {
                            ForEach(store.data.schedules) { schedule in
                                row(schedule, now: context.date)
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(store.data.schedules.isEmpty ? "Start with a ready-made schedule" : "Add another")
                        .font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 10)], spacing: 10) {
                        ForEach(FocusSchedule.presets) { preset in
                            presetCard(preset)
                        }
                        Button {
                            editing = FocusSchedule(name: "")
                        } label: {
                            card(icon: "plus", title: "Custom…", detail: "Choose your own days and times")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 820, alignment: .leading)
        }
        .navigationTitle("Schedules")
        .sheet(item: $editing) { schedule in
            ScheduleEditor(schedule: schedule) { store.saveSchedule($0) }
        }
    }

    private func row(_ schedule: FocusSchedule, now: Date) -> some View {
        let activeEnd = schedule.currentEnd(at: now)
        return HStack(spacing: 14) {
            Image(systemName: "calendar")
                .font(.title2)
                .foregroundStyle(schedule.isEnabled ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 3) {
                Text(schedule.name).font(.headline)
                Text("\(schedule.weekdaysText) · \(schedule.timeRangeText)").foregroundStyle(.secondary)
            }
            Spacer()
            status(schedule, activeEnd: activeEnd, now: now)
            Menu {
                Button("Edit…") { editing = schedule }
                Button("Delete", role: .destructive) { store.deleteSchedule(schedule) }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .disabled(store.isFocusActive)
            Toggle("On", isOn: Binding(
                get: { schedule.isEnabled },
                set: { store.setSchedule(schedule, enabled: $0) }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
            .disabled(store.isFocusActive && schedule.isEnabled)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.separator))
    }

    /// "Active now" or "Next: Tue 9:00". Shows what will happen without making people work it out.
    @ViewBuilder
    private func status(_ schedule: FocusSchedule, activeEnd: Date?, now: Date) -> some View {
        if activeEnd != nil {
            Text("Active now")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(.green.opacity(0.18), in: Capsule())
                .foregroundStyle(.green)
        } else if let next = schedule.nextStart(after: now) {
            Text("Next: \(next.formatted(.dateTime.weekday(.abbreviated).hour().minute()))")
                .font(.caption).foregroundStyle(.secondary)
        } else {
            Text("Off").font(.caption).foregroundStyle(.tertiary)
        }
    }

    private func presetCard(_ preset: FocusSchedule) -> some View {
        Button {
            store.saveSchedule(preset.copy())
        } label: {
            card(icon: preset.startMinutes > preset.endMinutes ? "moon.fill" : "sun.max.fill",
                 title: preset.name,
                 detail: "\(preset.weekdaysText) · \(preset.timeRangeText)")
        }
        .buttonStyle(.plain)
    }

    private func card(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(.tint).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).fontWeight(.medium)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 3])).foregroundStyle(.separator))
        .contentShape(Rectangle())
    }
}

struct ScheduleEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var schedule: FocusSchedule
    let onSave: (FocusSchedule) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(schedule.name.isEmpty ? "New schedule" : "Edit schedule").font(.title3.bold())

            VStack(alignment: .leading, spacing: 6) {
                Text("Name").font(.headline)
                TextField("e.g. Deep work", text: $schedule.name)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Days").font(.headline)
                HStack(spacing: 6) {
                    ForEach(Calendar.current.orderedWeekdays, id: \.self) { day in
                        let selected = schedule.weekdays.contains(day)
                        Button {
                            if selected { schedule.weekdays.remove(day) } else { schedule.weekdays.insert(day) }
                        } label: {
                            Text(Calendar.current.veryShortWeekdaySymbols[day - 1])
                                .fontWeight(.medium)
                                .frame(width: 34, height: 34)
                                .background(Circle().fill(selected ? Color.accentColor : Color(nsColor: .controlBackgroundColor)))
                                .foregroundStyle(selected ? .white : .primary)
                                .overlay(Circle().strokeBorder(selected ? .clear : Color(nsColor: .separatorColor)))
                        }
                        .buttonStyle(.plain)
                        .help(Calendar.current.weekdaySymbols[day - 1])
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Time").font(.headline)
                HStack(spacing: 16) {
                    DatePicker("From", selection: timeBinding(\.startMinutes), displayedComponents: .hourAndMinute)
                    DatePicker("to", selection: timeBinding(\.endMinutes), displayedComponents: .hourAndMinute)
                }
                .fixedSize()
                if schedule.endMinutes < schedule.startMinutes {
                    Label("Ends the next morning.", systemImage: "moon.fill").font(.caption).foregroundStyle(.secondary)
                }
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save") {
                    onSave(schedule)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
        }
        .padding(24)
        .frame(width: 440)
    }

    private var isValid: Bool {
        !schedule.weekdays.isEmpty && schedule.startMinutes != schedule.endMinutes
            && !schedule.name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func timeBinding(_ keyPath: WritableKeyPath<FocusSchedule, Int>) -> Binding<Date> {
        Binding {
            Calendar.current.date(byAdding: .minute, value: schedule[keyPath: keyPath],
                                  to: Calendar.current.startOfDay(for: .now)) ?? .now
        } set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            schedule[keyPath: keyPath] = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        }
    }
}
