import SwiftUI

/// First-run guide: show what the app does, then pick distractions, then set a passcode, then start.
/// Picking distractions comes before the passcode, so people get something useful before being asked for anything.
struct OnboardingView: View {
    @Environment(FocusStore.self) private var store

    private enum Step: Int, CaseIterable { case welcome, distractions, passcode, ready }
    @State private var step: Step = .welcome

    @State private var code = ""
    @State private var confirm = ""
    @State private var passcodeError: String?

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch step {
                case .welcome: welcome
                case .distractions: distractions
                case .passcode: passcode
                case .ready: ready
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(32)

            Divider()
            footer.padding(16)
        }
        .frame(width: 660, height: 560)
    }

    // MARK: Steps

    private var welcome: some View {
        VStack(spacing: 22) {
            Spacer()
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 112, height: 112)
            Text("Focus on one thing")
                .font(.system(size: 34, weight: .bold, design: .rounded))
            Text("Undistra removes distractions while you work, so you don't have to rely on willpower.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 460)

            VStack(alignment: .leading, spacing: 14) {
                feature("app.badge.checkmark", "Blocks distracting apps", "They close the moment they open.")
                feature("globe", "Blocks websites", "YouTube, Instagram and others won't load in any browser.")
                feature("key.fill", "Locked by a passcode", "Only your passcode can let you back in early.")
            }
            .padding(.top, 8)
            Spacer()
        }
    }

    private var distractions: some View {
        VStack(alignment: .leading, spacing: 18) {
            stepTitle("What usually distracts you?", "Tap to select. You can change this anytime.")
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Websites").font(.headline)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 10)], spacing: 10) {
                            ForEach(WebsiteCategory.all) { CategoryCard(category: $0) }
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Apps").font(.headline)
                        if !store.data.blockedApps.isEmpty {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 8)], alignment: .leading, spacing: 8) {
                                ForEach(store.data.blockedApps) { app in
                                    AppTile(app: app, isBlocked: true) { store.removeApp(app) }
                                }
                            }
                        }
                        AppSuggestions()
                    }
                }
            }
        }
    }

    private var passcode: some View {
        VStack(alignment: .leading, spacing: 18) {
            stepTitle("Create your passcode", "You'll need it to open a blocked app or end a session early.")

            VStack(alignment: .leading, spacing: 10) {
                SecureField("Passcode (at least 4 characters)", text: $code)
                SecureField("Type it again", text: $confirm)
                    .onSubmit(savePasscode)
                if let passcodeError {
                    Text(passcodeError).foregroundStyle(.red).font(.callout)
                }
            }
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: 360)

            Label {
                Text("**Tip:** a long, annoying passcode works best. Having to type it gives you a moment to ask “do I really need this?” For extra strength, ask a friend to set it for you.")
            } icon: {
                Image(systemName: "lightbulb.fill").foregroundStyle(.yellow)
            }
            .font(.callout)
            .padding(12)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
            .frame(maxWidth: 480)
            Spacer()
        }
    }

    private var ready: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)
            Text("You're all set")
                .font(.system(size: 32, weight: .bold, design: .rounded))
            Text(summaryText)
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 440)
            BlockPreview()
            Text("Try a short 25-minute session now to see how it feels.")
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            if step != .welcome {
                // "Step 2 of 3" makes the setup feel short, and people like to finish what they started.
                HStack(spacing: 6) {
                    ForEach(1..<Step.allCases.count, id: \.self) { index in
                        Capsule()
                            .fill(index <= step.rawValue ? Color.accentColor : Color(nsColor: .separatorColor))
                            .frame(width: index == step.rawValue ? 22 : 8, height: 8)
                    }
                    Text("Step \(step.rawValue) of \(Step.allCases.count - 1)")
                        .font(.caption).foregroundStyle(.secondary)
                        .padding(.leading, 4)
                }
                .animation(.snappy, value: step)
            }
            Spacer()
            switch step {
            case .welcome:
                Button("Get Started") { step = .distractions }
                    .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
            case .distractions:
                Button("Back") { step = .welcome }
                Button(nothingSelected ? "Skip for Now" : "Continue") {
                    step = store.hasPasscode ? .ready : .passcode
                }
                .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
            case .passcode:
                Button("Back") { step = .distractions }
                Button("Save Passcode", action: savePasscode)
                    .buttonStyle(.borderedProminent)
                    .disabled(code.isEmpty || confirm.isEmpty)
            case .ready:
                Button("I'll Start Later") { store.completeOnboarding() }
                Button("Start 25-min Session") {
                    store.completeOnboarding()
                    store.startSession(minutes: 25)
                }
                .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
            }
        }
        .controlSize(.large)
    }

    // MARK: Helpers

    private var nothingSelected: Bool {
        store.data.blockedApps.isEmpty && store.data.blockedWebsites.isEmpty
    }

    private var summaryText: String {
        let apps = store.data.blockedApps.count, sites = store.data.blockedWebsites.count
        if apps == 0 && sites == 0 { return "Add apps and websites in Block List whenever you're ready." }
        var parts: [String] = []
        if apps > 0 { parts.append("\(apps) app\(apps == 1 ? "" : "s")") }
        if sites > 0 { parts.append("\(sites) website\(sites == 1 ? "" : "s")") }
        return "During focus, \(parts.joined(separator: " and ")) will be blocked."
    }

    private func savePasscode() {
        do {
            try store.setPasscode(new: code, confirm: confirm, current: nil)
            passcodeError = nil
            step = .ready
        } catch {
            passcodeError = error.localizedDescription
        }
    }

    private func stepTitle(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 26, weight: .bold, design: .rounded))
            Text(subtitle).foregroundStyle(.secondary)
        }
    }

    private func feature(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).fontWeight(.semibold)
                Text(detail).foregroundStyle(.secondary)
            }
        }
    }
}
