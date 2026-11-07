import Foundation

/// Stores AppData as JSON in ~/Library/Application Support/Undistra/data.json.
struct Persistence {
    let url: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Undistra", isDirectory: true)
        let legacy = base.appendingPathComponent("FocusLock", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path), FileManager.default.fileExists(atPath: legacy.path) {
            try? FileManager.default.moveItem(at: legacy, to: dir) // keep data from before the rename
        }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("data.json")
    }()

    func load() -> AppData {
        guard let raw = try? Data(contentsOf: url) else { return AppData() }
        do {
            return try JSONDecoder().decode(AppData.self, from: raw)
        } catch {
            NSLog("Undistra: couldn't read saved data: \(error)")
            return AppData()
        }
    }

    func save(_ data: AppData) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(data).write(to: url, options: .atomic)
        } catch {
            NSLog("Undistra: couldn't save data: \(error)")
        }
    }
}
