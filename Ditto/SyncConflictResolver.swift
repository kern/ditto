import Foundation

/// Resolves conflicts between local and remote SwiftData state using the chosen strategy.
///
/// SwiftData + CloudKit syncs in the background. When the app comes to foreground,
/// the local context may have uncommitted changes while CloudKit has newer data.
/// This resolver reconciles the two snapshots according to the user's preference.
enum SyncConflictResolver {

    struct Snapshot {
        let categoryTitle: String
        let dittoText: String
        let modifiedAt: Date
    }

    /// Merges two snapshots of dittos (local + remote) for a single category.
    ///
    /// Rules for `.merge`:
    /// - All dittos present in exactly one snapshot are kept.
    /// - Dittos present in both (matched by text) → the one with the newer `modifiedAt` wins.
    /// - Relative sort order within each source is preserved; remote items are appended after local.
    static func merge(
        local: [Snapshot],
        remote: [Snapshot],
        resolution: ConflictResolution
    ) -> [Snapshot] {
        switch resolution {
        case .keepLocal:
            return local
        case .keepRemote:
            return remote
        case .merge:
            return smartMerge(local: local, remote: remote)
        }
    }

    // MARK: - Smart Merge

    private static func smartMerge(local: [Snapshot], remote: [Snapshot]) -> [Snapshot] {
        var result: [Snapshot] = []
        var remoteByText = Dictionary(uniqueKeysWithValues: remote.map { ($0.dittoText, $0) })

        // Walk local items, keeping the newer version of any conflict
        for localItem in local {
            if let remoteItem = remoteByText[localItem.dittoText] {
                // Both sides have this text — keep the newer one
                result.append(localItem.modifiedAt >= remoteItem.modifiedAt ? localItem : remoteItem)
                remoteByText.removeValue(forKey: localItem.dittoText)
            } else {
                // Only in local — keep it
                result.append(localItem)
            }
        }

        // Append any remote-only items (not in local)
        for remoteItem in remote where remoteByText[remoteItem.dittoText] != nil {
            result.append(remoteItem)
        }

        return result
    }

    /// Merges two snapshots of category titles.
    ///
    /// For `.merge`: union of all categories; same-title conflicts → newer modifiedAt wins.
    static func mergeCategories(
        local: [Snapshot],
        remote: [Snapshot],
        resolution: ConflictResolution
    ) -> [Snapshot] {
        switch resolution {
        case .keepLocal: return local
        case .keepRemote: return remote
        case .merge:
            var result: [Snapshot] = []
            var remoteByTitle = Dictionary(uniqueKeysWithValues: remote.map { ($0.categoryTitle, $0) })

            for localCat in local {
                if let remoteCat = remoteByTitle[localCat.categoryTitle] {
                    result.append(localCat.modifiedAt >= remoteCat.modifiedAt ? localCat : remoteCat)
                    remoteByTitle.removeValue(forKey: localCat.categoryTitle)
                } else {
                    result.append(localCat)
                }
            }
            for remoteCat in remote where remoteByTitle[remoteCat.categoryTitle] != nil {
                result.append(remoteCat)
            }
            return result
        }
    }
}
