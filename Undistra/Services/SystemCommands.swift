import Foundation

/// Runs a command line tool and waits for it to finish. Call it away from the main thread.
enum ProcessRunner {
    struct Output {
        let status: Int32
        let stdout: String
        let stderr: String
    }

    static func run(_ executable: String, _ arguments: [String]) throws -> Output {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let out = Pipe(), err = Pipe()
        process.standardOutput = out
        process.standardError = err
        try process.run()
        let outData = out.fileHandleForReading.readDataToEndOfFile()
        let errData = err.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return Output(status: process.terminationStatus,
                      stdout: String(decoding: outData, as: UTF8.self),
                      stderr: String(decoding: errData, as: UTF8.self))
    }
}

/// Blocks websites by keeping a marked section in /etc/hosts that points them to 0.0.0.0.
/// Changing /etc/hosts needs admin rights, so macOS asks for the password.
actor WebsiteBlocker {
    static let shared = WebsiteBlocker()

    private let hostsPath = "/etc/hosts"
    private let beginMarker = "# >>> Undistra BEGIN"
    private let endMarker = "# <<< Undistra END"
    // Markers from before the app was renamed, so an old block still gets cleaned up.
    private let legacyBegin = "# >>> FocusLock BEGIN"
    private let legacyEnd = "# <<< FocusLock END"

    enum BlockerError: LocalizedError {
        case cancelled
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .cancelled: "Websites weren't updated because the admin password prompt was cancelled."
            case .failed(let message): "Couldn't update blocked websites: \(message)"
            }
        }
    }

    /// Makes /etc/hosts block exactly `domains` (an empty list removes the block). Does nothing if already up to date.
    func apply(domains: [String]) throws {
        let current = (try? String(contentsOfFile: hostsPath, encoding: .utf8)) ?? ""
        var updated = stripSection(from: current)
        if !domains.isEmpty {
            if !updated.isEmpty && !updated.hasSuffix("\n") { updated += "\n" }
            updated += section(for: domains)
        }
        guard updated != current else { return }

        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("focuslock-hosts-\(UUID().uuidString)")
        try updated.write(to: temp, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: temp) }
        try installHosts(from: temp.path)
    }

    private func stripSection(from text: String) -> String {
        var kept: [Substring] = []
        var inside = false
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.hasPrefix(beginMarker) || line.hasPrefix(legacyBegin) { inside = true; continue }
            if line.hasPrefix(endMarker) || line.hasPrefix(legacyEnd) { inside = false; continue }
            if !inside { kept.append(line) }
        }
        return kept.joined(separator: "\n")
    }

    private func section(for domains: [String]) -> String {
        var lines = ["\(beginMarker) (managed by Undistra, don't edit)"]
        for domain in Set(domains).sorted() {
            for host in [domain, "www.\(domain)", "m.\(domain)"] {
                lines.append("0.0.0.0 \(host)")
                lines.append(":: \(host)")
            }
        }
        lines.append(endMarker)
        return lines.joined(separator: "\n") + "\n"
    }

    private func installHosts(from path: String) throws {
        // The file path is passed as an argument, so no shell escaping is needed in the script.
        let script = [
            "on run argv",
            "do shell script \"/bin/cp \" & quoted form of (item 1 of argv) & \" /etc/hosts && (/usr/bin/dscacheutil -flushcache; /usr/bin/killall -HUP mDNSResponder || true)\" with prompt \"Undistra needs your password to update blocked websites.\" with administrator privileges",
            "end run",
        ]
        let args = script.flatMap { ["-e", $0] } + [path]
        let result = try ProcessRunner.run("/usr/bin/osascript", args)
        guard result.status == 0 else {
            if result.stderr.contains("-128") { throw BlockerError.cancelled }
            throw BlockerError.failed(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
}

/// Turns a macOS Focus mode on or off by running a shortcut from the Shortcuts app.
/// Apple has no public API for apps to change Focus, so the user makes two small shortcuts with the "Set Focus" action.
enum FocusModeController {
    struct ShortcutError: LocalizedError {
        let name: String
        let message: String
        var errorDescription: String? { "Shortcut \"\(name)\" failed: \(message)" }
    }

    static func run(shortcut name: String) async throws {
        try await Task.detached(priority: .userInitiated) {
            let result = try ProcessRunner.run("/usr/bin/shortcuts", ["run", name])
            guard result.status == 0 else {
                let message = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
                throw ShortcutError(name: name, message: message.isEmpty ? "exit code \(result.status)" : message)
            }
        }.value
    }
}
