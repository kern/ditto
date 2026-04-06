import SwiftUI

/// Inline field that shows the selected category name and opens a picker on tap.
struct CategorySelectionField: View {

    let categoryName: String
    var isExpanded: Bool = false
    var onTap: () -> Void = {}

    var body: some View {
        Button(action: onTap) {
            HStack {
                Text("Category")
                    .foregroundStyle(.purple)
                Spacer()
                Text(isExpanded ? "Done" : categoryName)
                    .foregroundStyle(.purple)
                    .fontWeight(.bold)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack {
        CategorySelectionField(categoryName: "Business")
        CategorySelectionField(categoryName: "Business", isExpanded: true)
    }
}
