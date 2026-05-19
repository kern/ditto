import Foundation
import OSLog
import StoreKit

/// Manages the Ditto Pro subscription that unlocks iCloud sync.
@Observable
final class SubscriptionManager {

    static let proMonthlyProductID = "io.kern.ditto.pro.monthly"
    static let proYearlyProductID = "io.kern.ditto.pro.yearly"

    private static let log = Logger(subsystem: "io.kern.ditto", category: "SubscriptionManager")

    private(set) var products: [Product] = []
    private(set) var purchasedProductIDs: Set<String> = []
    private(set) var isLoading = false
    /// Diagnostic message from the last load attempt, surfaced to the UI when no products
    /// could be fetched. Empty string when products loaded successfully.
    private(set) var loadErrorMessage: String = ""

    var isProSubscriber: Bool {
        !purchasedProductIDs.isEmpty
    }

    private var updateTask: Task<Void, Never>?

    init(startListening: Bool = true) {
        guard startListening else { return }
        updateTask = Task { [weak self] in
            await self?.listenForTransactions()
        }
    }

    deinit {
        updateTask?.cancel()
    }

    // MARK: - Load Products

    @MainActor
    func loadProducts() async {
        isLoading = true
        loadErrorMessage = ""
        defer { isLoading = false }

        let productIDs = [Self.proMonthlyProductID, Self.proYearlyProductID]
        Self.log.info("loadProducts: requesting \(productIDs.count, privacy: .public) product IDs")

        // StoreKit can briefly return an empty array on cold launch before the
        // App Store connection is ready. Retry with backoff so we don't show a
        // false "Unable to load" to users (or to App Store reviewers).
        let backoff: [UInt64] = [0, 1_500_000_000, 3_000_000_000] // 0s, 1.5s, 3s
        for (attempt, delay) in backoff.enumerated() {
            if delay > 0 {
                try? await Task.sleep(nanoseconds: delay)
            }
            do {
                let fetched = try await Product.products(for: productIDs)
                Self.log.info(
                    "loadProducts: attempt \(attempt + 1, privacy: .public) returned \(fetched.count, privacy: .public) products"
                )
                if !fetched.isEmpty {
                    products = fetched.sorted { $0.price < $1.price }
                    return
                }
                // Empty result with no error usually means the products aren't
                // approved/published in App Store Connect, or the StoreKit
                // account hasn't synced yet. Continue retrying.
                loadErrorMessage = "No products returned from the App Store. They may still be pending review."
            } catch {
                Self.log.error(
                    "loadProducts: attempt \(attempt + 1, privacy: .public) failed: \(error.localizedDescription, privacy: .public)"
                )
                loadErrorMessage = error.localizedDescription
            }
        }

        Self.log.error("loadProducts: exhausted retries with no products")
    }

    // MARK: - Purchase

    @MainActor
    func purchase(_ product: Product) async throws -> Bool {
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            purchasedProductIDs.insert(transaction.productID)
            await transaction.finish()
            return true

        case .userCancelled:
            return false

        case .pending:
            return false

        @unknown default:
            return false
        }
    }

    // MARK: - Restore / Refresh

    /// Lightweight refresh — checks current entitlements without hitting the server.
    /// Safe to call on view appear.
    @MainActor
    func refreshEntitlements() async {
        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result) {
                purchasedProductIDs.insert(transaction.productID)
            }
        }
    }

    /// Full restore — syncs with the App Store server first, then refreshes entitlements.
    /// Only call when the user explicitly taps "Restore Purchases".
    @MainActor
    func restorePurchases() async throws {
        try await AppStore.sync()
        await refreshEntitlements()
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            if let transaction = try? checkVerified(result) {
                await MainActor.run {
                    purchasedProductIDs.insert(transaction.productID)
                }
                await transaction.finish()
            }
        }
    }

    // MARK: - Verification

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let item):
            return item
        }
    }

    enum StoreError: Error {
        case failedVerification
    }
}
