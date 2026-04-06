import SwiftUI

/// Section header view for category titles in the ditto list.
struct CategoryHeaderView: View {

    let title: String

    var body: some View {
        Text(title)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 15)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemGray6))
    }
}

#Preview {
    CategoryHeaderView(title: "Business")
}
