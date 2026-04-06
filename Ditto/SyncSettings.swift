import Foundation

/// Conflict resolution strategy when local and remote data differ.
enum ConflictResolution: String, CaseIterable, Codable {
    case merge // Union of local + remote, newest timestamp wins for same item
    case keepLocal // Local data always wins
    case keepRemote // Remote (iCloud) data always wins

    var displayName: String {
        switch self {
        case .merge: return String(localized: "Keep the newest edit")
        case .keepLocal: return String(localized: "Keep what's on this device")
        case .keepRemote: return String(localized: "Keep what's in iCloud")
        }
    }

    var description: String {
        switch self {
        case .merge: return String(localized: "Whichever device edited most recently wins")
        case .keepLocal: return String(localized: "Ignores any changes from your other devices")
        case .keepRemote: return String(localized: "Overwrites this device with your iCloud data")
        }
    }
}

/// Persisted iCloud sync preferences.
@Observable
final class SyncSettings {

    private static let defaults = UserDefaults(suiteName: "group.io.kern.ditto") ?? .standard
    private static let syncEnabledKey = "syncEnabled"
    private static let conflictResolutionKey = "conflictResolution"

    var syncEnabled: Bool {
        didSet { Self.defaults.set(syncEnabled, forKey: Self.syncEnabledKey) }
    }

    var conflictResolution: ConflictResolution {
        didSet { Self.defaults.set(conflictResolution.rawValue, forKey: Self.conflictResolutionKey) }
    }

    init() {
        let storedSync = Self.defaults.object(forKey: Self.syncEnabledKey) as? Bool
        syncEnabled = storedSync ?? true // default on for Pro users

        let storedResolution = Self.defaults.string(forKey: Self.conflictResolutionKey)
            .flatMap(ConflictResolution.init(rawValue:))
        conflictResolution = storedResolution ?? .merge
    }
}
