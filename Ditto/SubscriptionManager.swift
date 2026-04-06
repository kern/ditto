import Foundation
import StoreKit

/// Manages the Ditto Pro subscription that unlocks iCloud sync.
@Observable
final class SubscriptionManager {

    static let proMonthlyProductID = "io.kern.ditto.pro.monthly"
    static let proYearlyProductID = "io.kern.ditto.pro.yearly"

    private(set) var products: [Product] = []
    private(set) var purchasedProductIDs: Set<String> = []
    private(set) var isLoading = false

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
        defer { isLoading = false }

        do {
            products = try await Product.products(for: [
                Self.proMonthlyProductID,
                Self.proYearlyProductID
            ])
            products.sort { $0.price < $1.price }
        } catch {
            print("Failed to load products: \(error)")
        }
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
