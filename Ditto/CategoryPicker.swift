import SwiftUI

/// A picker view for selecting a category, used when creating/editing dittos.
struct CategoryPickerField: View {

    let categories: [DittoCategory]
    @Binding var selectedIndex: Int

    var body: some View {
        HStack {
            Text("Category")
                .foregroundStyle(.purple)
                .fontWeight(.semibold)
            Spacer()
            Picker("Category", selection: $selectedIndex) {
                ForEach(Array(categories.enumerated()), id: \.offset) { index, cat in
                    Text(cat.title).tag(index)
                }
            }
            .tint(.purple)
        }
    }
}
