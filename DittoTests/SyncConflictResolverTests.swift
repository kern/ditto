import Foundation
import Testing
@testable import Ditto

private typealias Snap = SyncConflictResolver.Snapshot

private func snap(_ text: String, daysAgo: Double = 0, category: String = "") -> Snap {
    Snap(categoryTitle: category, dittoText: text, modifiedAt: Date(timeIntervalSinceNow: -daysAgo * 86400))
}

@Suite("SyncConflictResolver Tests", .serialized)
struct SyncConflictResolverTests {

    // MARK: - keepLocal

    @Test("keepLocal returns local unchanged")
    func keepLocalReturnsLocal() {
        let local = [snap("A"), snap("B")]
        let remote = [snap("C"), snap("D")]
        let result = SyncConflictResolver.merge(local: local, remote: remote, resolution: .keepLocal)
        #expect(result.map(\.dittoText) == ["A", "B"])
    }

    // MARK: - keepRemote

    @Test("keepRemote returns remote unchanged")
    func keepRemoteReturnsRemote() {
        let local = [snap("A"), snap("B")]
        let remote = [snap("C"), snap("D")]
        let result = SyncConflictResolver.merge(local: local, remote: remote, resolution: .keepRemote)
        #expect(result.map(\.dittoText) == ["C", "D"])
    }

    // MARK: - merge: disjoint sets

    @Test("merge unions disjoint local and remote")
    func mergeDisjoint() {
        let local = [snap("Local1"), snap("Local2")]
        let remote = [snap("Remote1")]
        let result = SyncConflictResolver.merge(local: local, remote: remote, resolution: .merge)
        #expect(result.map(\.dittoText).sorted() == ["Local1", "Local2", "Remote1"])
    }

    // MARK: - merge: same text, local is newer

    @Test("merge keeps local when local is newer for same text")
    func mergeKeepsNewerLocal() {
        let local = [snap("Hello", daysAgo: 0)] // newer
        let remote = [snap("Hello", daysAgo: 2)] // older
        let result = SyncConflictResolver.merge(local: local, remote: remote, resolution: .merge)
        #expect(result.count == 1)
        #expect(result[0].modifiedAt >= remote[0].modifiedAt)
    }

    // MARK: - merge: same text, remote is newer

    @Test("merge keeps remote when remote is newer for same text")
    func mergeKeepsNewerRemote() {
        let local = [snap("Hello", daysAgo: 3)] // older
        let remote = [snap("Hello", daysAgo: 0)] // newer
        let result = SyncConflictResolver.merge(local: local, remote: remote, resolution: .merge)
        #expect(result.count == 1)
        #expect(result[0].modifiedAt >= local[0].modifiedAt)
    }

    // MARK: - merge: equal timestamps → local wins

    @Test("merge keeps local when timestamps are equal")
    func mergeEqualTimestamp() {
        let now = Date()
        let local = [Snap(categoryTitle: "", dittoText: "Same", modifiedAt: now)]
        let remote = [Snap(categoryTitle: "", dittoText: "Same", modifiedAt: now)]
        let result = SyncConflictResolver.merge(local: local, remote: remote, resolution: .merge)
        #expect(result.count == 1)
    }

    // MARK: - merge: mixed overlap

    @Test("merge handles partial overlap correctly")
    func mergeMixed() {
        let local = [snap("OnlyLocal"), snap("Shared", daysAgo: 1)]
        let remote = [snap("Shared", daysAgo: 5), snap("OnlyRemote")]
        let result = SyncConflictResolver.merge(local: local, remote: remote, resolution: .merge)
        let texts = Set(result.map(\.dittoText))
        #expect(texts == ["OnlyLocal", "Shared", "OnlyRemote"])
        // Shared: local (1 day ago) is newer than remote (5 days ago)
        let shared = result.first { $0.dittoText == "Shared" }!
        #expect(shared.modifiedAt > remote[0].modifiedAt)
    }

    // MARK: - empty inputs

    @Test("merge with empty local returns remote")
    func mergeEmptyLocal() {
        let remote = [snap("R1"), snap("R2")]
        let result = SyncConflictResolver.merge(local: [], remote: remote, resolution: .merge)
        #expect(result.map(\.dittoText).sorted() == ["R1", "R2"])
    }

    @Test("merge with empty remote returns local")
    func mergeEmptyRemote() {
        let local = [snap("L1"), snap("L2")]
        let result = SyncConflictResolver.merge(local: local, remote: [], resolution: .merge)
        #expect(result.map(\.dittoText).sorted() == ["L1", "L2"])
    }

    @Test("merge with both empty returns empty")
    func mergeBothEmpty() {
        let result = SyncConflictResolver.merge(local: [], remote: [], resolution: .merge)
        #expect(result.isEmpty)
    }

    // MARK: - category merge

    @Test("mergeCategories unions disjoint categories")
    func mergeCategoriesDisjoint() {
        let local = [Snap(categoryTitle: "Work", dittoText: "", modifiedAt: .now)]
        let remote = [Snap(categoryTitle: "Home", dittoText: "", modifiedAt: .now)]
        let result = SyncConflictResolver.mergeCategories(local: local, remote: remote, resolution: .merge)
        #expect(Set(result.map(\.categoryTitle)) == ["Work", "Home"])
    }

    @Test("mergeCategories keepLocal")
    func mergeCategoriesKeepLocal() {
        let local = [Snap(categoryTitle: "Work", dittoText: "", modifiedAt: .now)]
        let remote = [Snap(categoryTitle: "Home", dittoText: "", modifiedAt: .now)]
        let result = SyncConflictResolver.mergeCategories(local: local, remote: remote, resolution: .keepLocal)
        #expect(result.map(\.categoryTitle) == ["Work"])
    }

    @Test("mergeCategories keepRemote")
    func mergeCategoriesKeepRemote() {
        let local = [Snap(categoryTitle: "Work", dittoText: "", modifiedAt: .now)]
        let remote = [Snap(categoryTitle: "Home", dittoText: "", modifiedAt: .now)]
        let result = SyncConflictResolver.mergeCategories(local: local, remote: remote, resolution: .keepRemote)
        #expect(result.map(\.categoryTitle) == ["Home"])
    }

    @Test("mergeCategories same title newer remote wins")
    func mergeCategoriesSameTitleRemoteNewer() {
        let local = [Snap(categoryTitle: "Work", dittoText: "", modifiedAt: Date(timeIntervalSinceNow: -86400))]
        let remote = [Snap(categoryTitle: "Work", dittoText: "", modifiedAt: Date())]
        let result = SyncConflictResolver.mergeCategories(local: local, remote: remote, resolution: .merge)
        #expect(result.count == 1)
        #expect(result[0].modifiedAt >= local[0].modifiedAt)
    }
}

// MARK: - SyncSettings Tests

@Suite("SyncSettings Tests")
struct SyncSettingsTests {

    @Test("Default conflict resolution is merge")
    func defaultResolutionIsMerge() {
        // Clear any stored value first
        let defaults = UserDefaults(suiteName: "group.io.kern.ditto")
        defaults?.removeObject(forKey: "conflictResolution")
        let settings = SyncSettings()
        #expect(settings.conflictResolution == .merge)
    }

    @Test("ConflictResolution allCases has three options")
    func allCasesCount() {
        #expect(ConflictResolution.allCases.count == 3)
    }

    @Test("ConflictResolution displayNames are non-empty")
    func displayNamesNonEmpty() {
        for resolution in ConflictResolution.allCases {
            #expect(!resolution.displayName.isEmpty)
            #expect(!resolution.description.isEmpty)
        }
    }
}
