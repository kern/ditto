import SwiftUI

/// Sync configuration screen for Ditto Pro subscribers.
struct SyncSettingsView: View {

    @Bindable var settings: SyncSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Enable iCloud Sync", isOn: $settings.syncEnabled)
                } footer: {
                    Text("Sync your dittos across all your Apple devices using iCloud.")
                }

                if settings.syncEnabled {
                    Section {
                        ForEach(ConflictResolution.allCases, id: \.self) { option in
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(option.displayName)
                                        .foregroundStyle(.primary)
                                    Text(option.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if settings.conflictResolution == option {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.dittoAccent)
                                        .fontWeight(.semibold)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { settings.conflictResolution = option }
                        }
                    } header: {
                        Text("When devices disagree")
                    } footer: {
                        Text("If you edit a ditto on two devices before they sync, this setting decides which version to keep.")
                    }
                }
            }
            .navigationTitle("Sync Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
