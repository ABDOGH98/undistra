import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case session, blockList, schedules, settings
    var id: Self { self }

    var title: String {
        switch self {
        case .session: "Focus"
        case .blockList: "Block List"
        case .schedules: "Schedules"
        case .settings: "Settings"
        }
    }

    var icon: String {
        switch self {
        case .session: "scope"
        case .blockList: "nosign"
        case .schedules: "calendar"
        case .settings: "gearshape"
        }
    }
}

struct ContentView: View {
    @Environment(FocusStore.self) private var store
    @State private var selection: SidebarItem? = .session

    var body: some View {
        NavigationSplitView {
            List(SidebarItem.allCases, selection: $selection) { item in
                Label(item.title, systemImage: item.icon)
                    .badge(badge(for: item))
                    .tag(item)
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 210)
            .safeAreaInset(edge: .bottom) { statusCard.padding(10) }
        } detail: {
            VStack(spacing: 0) {
                if let error = store.lastError {
                    ErrorBanner(message: error) { store.lastError = nil }
                }
                detail
            }
        }
        .sheet(isPresented: Binding(get: { !store.data.hasCompletedOnboarding }, set: { _ in })) {
            OnboardingView()
                .interactiveDismissDisabled()
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch selection ?? .session {
        case .session: SessionView { selection = .blockList }
        case .blockList: BlockListView()
        case .schedules: SchedulesView()
        case .settings: SettingsView()
        }
    }

    private func badge(for item: SidebarItem) -> Int {
        item == .blockList ? store.data.blockedApps.count + store.data.blockedWebsites.count : 0
    }

    /// Always-visible session status (same place every time, so it's easy to find).
    private var statusCard: some View {
        HStack(spacing: 8) {
            Image(systemName: store.isFocusActive ? "lock.fill" : "lock.open")
                .foregroundStyle(store.isFocusActive ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
            VStack(alignment: .leading, spacing: 1) {
                Text(store.isFocusActive ? "Focus is on" : "Focus is off").font(.callout.weight(.medium))
                if store.isFocusActive, let until = store.activeUntil {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text("\(TimeFormat.countdown(until.timeIntervalSince(context.date))) left")
                            .font(.caption).monospacedDigit().foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
        }
        .padding(10)
        .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
    }
}
