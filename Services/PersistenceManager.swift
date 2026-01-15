import Foundation

/// Lightweight local cache for daily snapshots and sync metadata.
actor PersistenceManager {
    
    enum PersistenceError: LocalizedError {
        case saveFailed(String)
        case loadFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .saveFailed(let reason):
                return "Failed to save data: \(reason)"
            case .loadFailed(let reason):
                return "Failed to load data: \(reason)"
            }
        }
    }
    
    private let fileManager = FileManager.default
    private let applicationSupportURL: URL
    private let snapshotsFile: URL
    private let syncDateFile: URL
    
    init() throws {
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw PersistenceError.saveFailed("Unable to access Application Support directory")
        }
        
        let appDir = appSupport.appendingPathComponent("VitalBrief", isDirectory: true)
        try fileManager.createDirectory(at: appDir, withIntermediateDirectories: true)
        
        self.applicationSupportURL = appDir
        self.snapshotsFile = appDir.appendingPathComponent("snapshots.json")
        self.syncDateFile = appDir.appendingPathComponent("syncDate.json")
    }
    
    /// Saves snapshots to cache.
    func saveSnapshots(_ snapshots: [DailySnapshot]) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        let data = try encoder.encode(snapshots)
        do {
            try data.write(to: snapshotsFile)
        } catch {
            throw PersistenceError.saveFailed(error.localizedDescription)
        }
    }
    
    /// Loads cached snapshots. Returns empty array if none exist.
    func loadSnapshots() throws -> [DailySnapshot] {
        guard fileManager.fileExists(atPath: snapshotsFile.path) else {
            return []
        }
        
        do {
            let data = try Data(contentsOf: snapshotsFile)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([DailySnapshot].self, from: data)
        } catch {
            throw PersistenceError.loadFailed(error.localizedDescription)
        }
    }
    
    /// Saves the last successful sync timestamp.
    func saveSyncDate(_ date: Date) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        let data = try encoder.encode(date)
        do {
            try data.write(to: syncDateFile)
        } catch {
            throw PersistenceError.saveFailed(error.localizedDescription)
        }
    }
    
    /// Loads the last successful sync timestamp. Returns nil if none exist.
    func loadSyncDate() throws -> Date? {
        guard fileManager.fileExists(atPath: syncDateFile.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: syncDateFile)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(Date.self, from: data)
        } catch {
            throw PersistenceError.loadFailed(error.localizedDescription)
        }
    }
    
    /// Clears all cached data.
    func clearCache() throws {
        do {
            try fileManager.removeItem(at: snapshotsFile)
        } catch where (error as NSError).code != NSFileNoSuchFileError {
            throw PersistenceError.saveFailed("Failed to clear snapshots: \(error.localizedDescription)")
        }
        
        do {
            try fileManager.removeItem(at: syncDateFile)
        } catch where (error as NSError).code != NSFileNoSuchFileError {
            throw PersistenceError.saveFailed("Failed to clear sync date: \(error.localizedDescription)")
        }
    }
}
