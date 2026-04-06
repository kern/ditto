import SwiftUI

/// Sheet view for creating a new category or ditto.
struct NewItemView: View {

    let store: DittoStore
    let objectType: DittoObjectType

    @Environment(\.dismiss) private var dismiss

    @State private var text: String = ""
    @State private var selectedCategoryIndex: Int = 0

    private var title: String {
        switch objectType {
        case .category: return "New Category"
        case .ditto: return "New Ditto"
        }
    }

    private var showCategoryPicker: Bool {
        objectType == .ditto && store.categoryCount > 1
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if showCategoryPicker {
                    HStack {
                        Text("Category")
                            .foregroundStyle(.purple)
                        Spacer()
                        Picker("Category", selection: $selectedCategoryIndex) {
                            ForEach(Array(store.categories.enumerated()), id: \.offset) { index, cat in
                                Text(cat.title).tag(index)
                            }
                        }
                        .tint(.purple)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    Divider()
                }

                TextEditor(text: $text)
                    .padding(6)
                    .scrollContentBackground(.hidden)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.purple, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveAndDismiss() }
                        .bold()
                        .disabled(text.isEmpty)
                }
            }
        }
    }

    private func saveAndDismiss() {
        switch objectType {
        case .category:
            store.addCategory(title: text)

        case .ditto:
            if store.isEmpty {
                store.addCategory(title: "General")
            }
            store.addDitto(text: text, toCategoryAt: selectedCategoryIndex)
        }
        dismiss()
    }
}
