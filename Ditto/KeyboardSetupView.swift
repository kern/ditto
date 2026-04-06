import SwiftUI

/// Detects whether the Ditto keyboard is fully set up.
struct KeyboardSetupStatus {
    /// True if the keyboard extension has ever loaded (written to shared UserDefaults).
    /// This confirms the keyboard is added AND full access is granted.
    static var hasFullAccess: Bool {
        UserDefaults(suiteName: "group.io.kern.ditto")?.bool(forKey: "keyboardHasLoaded") ?? false
    }
}

/// Step-by-step setup instructions for adding the Ditto keyboard.
struct KeyboardSetupView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var hasFullAccess = KeyboardSetupStatus.hasFullAccess

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 10) {
                        Image(systemName: "keyboard")
                            .font(.system(size: 52))
                            .foregroundStyle(.dittoAccent)
                        Text("Set Up Ditto Keyboard")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Follow these steps to use Ditto anywhere you type.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 32)

                    // Steps
                    VStack(spacing: 0) {
                        SetupStep(
                            number: 1,
                            title: "Open Settings",
                            detail: "Go to Settings → General → Keyboard → Keyboards",
                            isComplete: hasFullAccess,
                            isLast: false
                        )
                        SetupStep(
                            number: 2,
                            title: "Add Ditto",
                            detail: "Tap \"Add New Keyboard\" and select Ditto from the list",
                            isComplete: hasFullAccess,
                            isLast: false
                        )
                        SetupStep(
                            number: 3,
                            title: "Allow Full Access",
                            detail: "Tap Ditto in the keyboard list and enable \"Allow Full Access\" so it can read your snippets",
                            isComplete: hasFullAccess,
                            isLast: true
                        )
                    }
                    .padding(.horizontal, 24)

                    // Status badge
                    if hasFullAccess {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Ditto keyboard is active")
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.green.opacity(0.1), in: Capsule())
                    } else {
                        Button {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "gear")
                                Text("Open Settings")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.dittoAccent, in: RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 24)

                        Text("Come back here after enabling — we'll detect it automatically.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                .padding(.bottom, 32)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { refresh() }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                refresh()
            }
        }
    }

    private func refresh() {
        hasFullAccess = KeyboardSetupStatus.hasFullAccess
    }
}

private struct SetupStep: View {
    let number: Int
    let title: String
    let detail: String
    let isComplete: Bool
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(isComplete ? Color.green : Color.dittoAccent)
                        .frame(width: 32, height: 32)
                    if isComplete {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                    } else {
                        Text("\(number)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                if !isLast {
                    Rectangle()
                        .fill(Color(.systemGray4))
                        .frame(width: 2)
                        .frame(minHeight: 32)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, isLast ? 0 : 24)

            Spacer()
        }
    }
}
