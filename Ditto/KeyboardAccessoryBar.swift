import SwiftUI

/// Keyboard accessory toolbar showing the selected category for ditto editing.
struct KeyboardAccessoryBar: View {

    let categories: [DittoCategory]
    @Binding var selectedCategoryIndex: Int
    @State private var isPickerExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Category")
                    .foregroundStyle(.purple)
                Spacer()
                if isPickerExpanded {
                    Button("Done") {
                        isPickerExpanded = false
                    }
                    .foregroundStyle(.purple)
                    .fontWeight(.bold)
                } else {
                    Button(categories.indices.contains(selectedCategoryIndex) ? categories[selectedCategoryIndex].title : "") {
                        isPickerExpanded = true
                    }
                    .foregroundStyle(.purple)
                    .fontWeight(.bold)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))

            if isPickerExpanded {
                Picker("Category", selection: $selectedCategoryIndex) {
                    ForEach(Array(categories.enumerated()), id: \.offset) { index, cat in
                        Text(cat.title).tag(index)
                    }
                }
                .pickerStyle(.wheel)
                .background(Color(.systemGray6))
            }
        }
    }
}
