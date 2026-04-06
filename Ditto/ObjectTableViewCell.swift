import SwiftUI

/// A reusable row view for displaying ditto or category text in a list.
struct DittoRowView: View {

    let text: String
    var showDisclosure: Bool = true

    var body: some View {
        HStack {
            Text(text)
                .lineLimit(2)
            Spacer()
            if showDisclosure {
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    List {
        DittoRowView(text: "Hello, this is a sample ditto text")
        DittoRowView(text: "Short one")
        DittoRowView(text: "A very long ditto that should be truncated after two lines because it contains so much text that it would overflow", showDisclosure: false)
    }
}
