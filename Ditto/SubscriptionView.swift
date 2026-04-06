import StoreKit
import SwiftUI

/// Paywall view showing Ditto Pro subscription options for iCloud sync.
struct SubscriptionView: View {

    let subscriptionManager: SubscriptionManager

    @Environment(\.dismiss) private var dismiss
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var errorMessage: String?
    @State private var restoreMessage: String?
    @State private var selectedProduct: Product?

    var body: some View {
        NavigationStack {
            ScrollView {
                if subscriptionManager.isProSubscriber {
                    subscribedContent
                } else {
                    paywallContent
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                await subscriptionManager.loadProducts()
                await subscriptionManager.refreshEntitlements()
            }
        }
    }

    private var subscribedPlanLabel: String {
        if subscriptionManager.purchasedProductIDs.contains(SubscriptionManager.proYearlyProductID) {
            return "Yearly plan"
        } else if subscriptionManager.purchasedProductIDs.contains(SubscriptionManager.proMonthlyProductID) {
            return "Monthly plan"
        }
        return "You're subscribed"
    }

    private var subscribedContent: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Image(systemName: "checkmark.icloud.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.dittoAccent)

                Text("Ditto Pro")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text(subscribedPlanLabel)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 40)

            VStack(alignment: .leading, spacing: 16) {
                featureRow(
                    icon: "checkmark.circle.fill",
                    title: "iCloud Sync",
                    description: "Your dittos sync across all your devices"
                )
                featureRow(
                    icon: "checkmark.circle.fill",
                    title: "Import & Export",
                    description: "Back up and share your ditto collections"
                )
                featureRow(
                    icon: "checkmark.circle.fill",
                    title: "Private & Secure",
                    description: "Your data is encrypted in your personal iCloud"
                )
            }
            .padding(.horizontal, 24)

            Text("Thank you for supporting Ditto!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 8)

            Button("Manage Subscription") {
                if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                    UIApplication.shared.open(url)
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.bottom, 32)
        }
    }

    private var paywallContent: some View {
        VStack(spacing: 28) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "icloud.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.dittoAccent)

                Text("Ditto Pro")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Unlock the full power of Ditto")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.top, 32)

            // Features
            VStack(alignment: .leading, spacing: 16) {
                featureRow(
                    icon: "arrow.triangle.2.circlepath",
                    title: "iCloud Sync",
                    description: "Access your dittos on all your Apple devices"
                )
                featureRow(
                    icon: "square.and.arrow.up.on.square",
                    title: "Import & Export",
                    description: "Back up and share your ditto collections"
                )
                featureRow(
                    icon: "lock.shield",
                    title: "Private & Secure",
                    description: "Your data stays encrypted in your personal iCloud"
                )
            }
            .padding(.horizontal, 24)

            // Products
            if subscriptionManager.isLoading {
                ProgressView()
                    .padding()
            } else if subscriptionManager.products.isEmpty {
                VStack(spacing: 8) {
                    Text("Unable to load subscription options.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("Try Again") {
                        Task { await subscriptionManager.loadProducts() }
                    }
                    .font(.subheadline)
                }
                .padding()
            } else {
                VStack(spacing: 12) {
                    let monthlyPrice = subscriptionManager.products.first {
                        $0.id == SubscriptionManager.proMonthlyProductID
                    }?.price
                    ForEach(subscriptionManager.products, id: \.id) { product in
                        ProductCard(
                            product: product,
                            monthlyPrice: product.id == SubscriptionManager.proYearlyProductID ? monthlyPrice : nil,
                            isSelected: selectedProduct?.id == product.id,
                            isPurchasing: isPurchasing
                        ) {
                            selectedProduct = product
                        }
                    }
                }
                .padding(.horizontal, 24)
                .onAppear {
                    if selectedProduct == nil {
                        selectedProduct = subscriptionManager.products.first {
                            $0.id == SubscriptionManager.proYearlyProductID
                        } ?? subscriptionManager.products.last
                    }
                }

                // Subscribe button
                Button {
                    guard let product = selectedProduct else { return }
                    Task { await purchaseProduct(product) }
                } label: {
                    Text("Subscribe")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.dittoAccent, in: RoundedRectangle(cornerRadius: 14))
                }
                .disabled(isPurchasing || selectedProduct == nil)
                .padding(.horizontal, 24)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            // Restore
            if isRestoring {
                ProgressView()
                    .padding(.bottom, 24)
            } else {
                VStack(spacing: 6) {
                    Button("Restore Purchases") {
                        Task { await restore() }
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    if let restoreMessage {
                        Text(restoreMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.bottom, 24)
            }
        }
    }

    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.dittoAccent)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func purchaseProduct(_ product: Product) async {
        isPurchasing = true
        defer { isPurchasing = false }
        errorMessage = nil

        do {
            let success = try await subscriptionManager.purchase(product)
            if success {
                dismiss()
            }
        } catch {
            errorMessage = "Purchase failed. Please try again."
        }
    }

    private func restore() async {
        isRestoring = true
        restoreMessage = nil
        defer { isRestoring = false }

        do {
            try await subscriptionManager.restorePurchases()
            restoreMessage = subscriptionManager.isProSubscriber
                ? "Subscription restored."
                : "No active subscription found."
        } catch {
            restoreMessage = "Restore failed. Please try again."
        }
    }
}

/// A selectable card for a StoreKit product.
private struct ProductCard: View {

    let product: Product
    let monthlyPrice: Decimal? // nil when this card IS the monthly option
    let isSelected: Bool
    let isPurchasing: Bool
    let action: () -> Void

    private var isYearly: Bool {
        product.id == SubscriptionManager.proYearlyProductID
    }

    private var savingsText: String? {
        guard isYearly, let monthly = monthlyPrice, monthly > 0 else { return nil }
        let annualized = monthly * 12
        guard annualized > product.price else { return nil }
        let pct = Int(NSDecimalNumber(decimal: (annualized - product.price) / annualized * 100).rounding(accordingToBehavior: nil).intValue)
        guard pct > 0 else { return nil }
        return "Save \(pct)%"
    }

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isYearly ? "Yearly" : "Monthly")
                        .font(.headline)
                    if let savingsText {
                        Text(savingsText)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.dittoAccent)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(product.displayPrice)
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text(isYearly ? "per year" : "per month")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color.dittoAccent.opacity(0.08) : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.dittoAccent : Color(.systemGray4), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isPurchasing)
    }
}
