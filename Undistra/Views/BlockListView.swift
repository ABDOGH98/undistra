import SwiftUI

/// Apps and websites in one place, with suggestions so people can pick instead of remember.
struct BlockListView: View {
    @Environment(FocusStore.self) private var store
    @State private var websiteInput = ""
    @State private var invalidWebsite = false

    private let columns = [GridItem(.adaptive(minimum: 170), spacing: 8)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                if store.isFocusActive { LockedNotice() }
                appsSection
                Divider()
                websitesSection
            }
            .padding(24)
            .frame(maxWidth: 820, alignment: .leading)
        }
        .navigationTitle("Block List")
    }

    // MARK: Apps

    private var appsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                SectionHeader(title: "Apps",
                              subtitle: "Closed as soon as they open during focus. Your passcode opens them for a few minutes.",
                              count: store.data.blockedApps.count)
                Spacer()
                Button("Choose Another App…") { pickOtherApps(into: store) }
            }

            if store.data.blockedApps.isEmpty {
                Text("No apps blocked yet. Pick from the suggestions below.")
                    .font(.callout).foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                    ForEach(store.data.blockedApps) { app in
                        AppTile(app: app, isBlocked: true, disabled: store.isFocusActive) { store.removeApp(app) }
                    }
                }
            }

            DisclosureGroup {
                AppSuggestions().padding(.top, 8)
            } label: {
                Text("Suggestions").font(.subheadline.weight(.medium))
            }
        }
    }

    // MARK: Websites

    private var websitesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Websites",
                          subtitle: "Won't load in any browser during focus. Includes www. and mobile versions.",
                          count: store.data.blockedWebsites.count)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 10)], spacing: 10) {
                ForEach(WebsiteCategory.all) { CategoryCard(category: $0) }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    TextField("Add a website, e.g. example.com", text: $websiteInput)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(addWebsite)
                        .onChange(of: websiteInput) { invalidWebsite = false }
                    Button("Add", action: addWebsite).disabled(websiteInput.isEmpty)
                }
                .frame(maxWidth: 460)
                if invalidWebsite {
                    Text("That doesn't look like a website address.").font(.callout).foregroundStyle(.red)
                }
            }

            if !store.data.blockedWebsites.isEmpty {
                FlowChips(domains: store.data.blockedWebsites.map(\.domain))
            }

            Label("A page that's already open may keep working until you reload it or restart the browser.",
                  systemImage: "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func addWebsite() {
        if store.addWebsite(websiteInput) {
            websiteInput = ""
        } else {
            invalidWebsite = true
        }
    }
}

/// Blocked websites as removable chips.
private struct FlowChips: View {
    @Environment(FocusStore.self) private var store
    let domains: [String]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 6, alignment: .leading)], alignment: .leading, spacing: 6) {
            ForEach(domains, id: \.self) { domain in
                WebsiteChip(domain: domain, isBlocked: true, disabled: store.isFocusActive) {
                    store.removeWebsite(BlockedWebsite(domain: domain))
                }
                .help("Stop blocking \(domain)")
            }
        }
    }
}
