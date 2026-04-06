import SwiftUI
import StoreKit

/// Paywall view showing Ditto Pro subscription options for iCloud sync.
struct SubscriptionView: View {

    let subscriptionManager: SubscriptionManager

    @Environment(\.dismiss) private var dismiss
    @State private var isPurchasing = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "icloud.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.purple)

                        Text("Ditto Pro")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("Sync your dittos across all your devices with iCloud")
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
                        featureRow(icon: "lock.shield", title: "Private & Secure", description: "Your data stays encrypted in your personal iCloud")
                        featureRow(icon: "bolt.fill", title: "Instant Updates", description: "Changes sync automatically in real-time")
                    }
                    .padding(.horizontal, 24)

                    // Products
                    if subscriptionManager.isLoading {
                        ProgressView()
                            .padding()
                    } else {
                        VStack(spacing: 12) {
                            ForEach(subscriptionManager.products, id: \.id) { product in
                                ProductButton(product: product, isPurchasing: isPurchasing) {
                                    await purchaseProduct(product)
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal)
                    }

                    // Restore
                    Button("Restore Purchases") {
                        Task {
                            await subscriptionManager.restorePurchases()
                            if subscriptionManager.isProSubscriber {
                                dismiss()
                            }
                        }
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 24)
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
                await subscriptionManager.restorePurchases()
                if subscriptionManager.isProSubscriber {
                    dismiss()
                }
            }
        }
    }

    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.purple)
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
}

/// A styled button for a StoreKit product.
private struct ProductButton: View {

    let product: Product
    let isPurchasing: Bool
    let action: () async -> Void

    private var isYearly: Bool {
        product.id == SubscriptionManager.proYearlyProductID
    }

    var body: some View {
        Button {
            Task { await action() }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(isYearly ? "Yearly" : "Monthly")
                        .font(.headline)
                    if isYearly {
                        Text("Best value")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }

                Spacer()

                Text(product.displayPrice)
                    .font(.headline)
                Text(isYearly ? "/year" : "/month")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isYearly ? Color.purple.opacity(0.1) : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isYearly ? Color.purple : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .disabled(isPurchasing)
    }
}
