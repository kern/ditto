import SwiftUI

/// Sheet view for editing an existing category or ditto.
struct EditItemView: View {

    let store: DittoStore
    let target: EditTarget

    @Environment(\.dismiss) private var dismiss

    @State private var text: String = ""
    @State private var selectedCategoryIndex: Int = 0
    @FocusState private var isTextFocused: Bool

    private var title: String {
        switch target {
        case .category: return "Edit Category"
        case .ditto: return "Edit Ditto"
        }
    }

    private var showCategoryPicker: Bool {
        if case .ditto = target { return store.categoryCount > 1 }
        return false
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if showCategoryPicker {
                    HStack {
                        Text("Category")
                            .foregroundStyle(.dittoAccent)
                        Spacer()
                        Picker("Category", selection: $selectedCategoryIndex) {
                            ForEach(Array(store.categories.enumerated()), id: \.offset) { index, cat in
                                Text(cat.title).tag(index)
                            }
                        }
                        .tint(.dittoAccent)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    Divider()
                }

                TextEditor(text: $text)
                    .focused($isTextFocused)
                    .padding(6)
                    .scrollContentBackground(.hidden)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.dittoAccent, for: .navigationBar)
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
        .onAppear {
            loadCurrentValues()
            isTextFocused = true
        }
    }

    private func loadCurrentValues() {
        switch target {
        case .category(let index):
            text = store.category(at: index).title

        case .ditto(let catIndex, let dittoIndex):
            text = store.ditto(inCategoryAt: catIndex, at: dittoIndex).text
            selectedCategoryIndex = catIndex
        }
    }

    private func saveAndDismiss() {
        switch target {
        case .category(let index):
            store.updateCategory(at: index, title: text)

        case .ditto(let catIndex, let dittoIndex):
            store.updateDitto(inCategoryAt: catIndex, at: dittoIndex, text: text)
            if selectedCategoryIndex != catIndex {
                store.moveDitto(fromCategory: catIndex, fromIndex: dittoIndex, toCategory: selectedCategoryIndex)
            }
        }
        dismiss()
    }
}
