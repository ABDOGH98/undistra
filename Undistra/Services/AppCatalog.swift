import AppKit

/// Finds apps to suggest, so people can pick from a list instead of remembering what distracts them.
enum AppCatalog {
    /// Apps that commonly pull attention away from work.
    static let commonDistractions = [
        "com.tinyspeck.slackmacgap", "com.hnc.Discord", "com.apple.MobileSMS", "com.apple.mail",
        "ru.keepcoder.Telegram", "net.whatsapp.WhatsApp", "desktop.WhatsApp", "com.facebook.archon",
        "com.microsoft.teams2", "com.valvesoftware.steam", "com.spotify.client", "com.apple.Music",
        "com.apple.TV", "com.apple.news", "com.apple.podcasts", "com.apple.FaceTime",
    ]

    private static let neverBlock: Set<String> = [
        "com.apple.finder", "com.apple.systempreferences", "com.apple.loginwindow",
    ]

    static func app(at url: URL) -> BlockedApp? {
        guard let id = Bundle(url: url)?.bundleIdentifier else { return nil }
        let name = FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
        return BlockedApp(bundleID: id, name: name, path: url.path)
    }

    static func canBlock(_ bundleID: String) -> Bool {
        bundleID != Bundle.main.bundleIdentifier && !neverBlock.contains(bundleID)
    }

    /// Apps that are open right now, then common distractions that are installed. Leaves out `excluding`.
    static func suggestions(excluding: Set<String>) -> (open: [BlockedApp], common: [BlockedApp]) {
        let open = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { $0.bundleURL.flatMap(app(at:)) }
            .filter { canBlock($0.bundleID) && !excluding.contains($0.bundleID) }
        let openIDs = Set(open.map(\.bundleID))

        let common = commonDistractions
            .filter { !excluding.contains($0) && !openIDs.contains($0) }
            .compactMap { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0).flatMap(app(at:)) }

        let byName: (BlockedApp, BlockedApp) -> Bool = {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        return (unique(open).sorted(by: byName), unique(common).sorted(by: byName))
    }

    private static func unique(_ apps: [BlockedApp]) -> [BlockedApp] {
        var seen = Set<String>()
        return apps.filter { seen.insert($0.bundleID).inserted }
    }
}
