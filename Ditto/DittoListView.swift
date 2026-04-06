import SwiftUI

/// Main list view showing either categories or dittos with a segmented control toggle.
struct DittoListView: View {

    @State var store: DittoStore
    var subscriptionManager: SubscriptionManager

    @State private var objectType: DittoObjectType = .ditto
    @State private var isEditing = false
    @State private var showNewSheet = false
    @State private var editTarget: EditTarget?
    @State private var showMaxCategoryAlert = false
    @State private var categoryToDelete: Int?
    @State private var showSubscription = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("View", selection: $objectType) {
                    ForEach(DittoObjectType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .disabled(isEditing)

                listContent
            }
            .navigationTitle("Ditto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.purple, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if isEditing {
                        Button("Done") {
                            isEditing = false
                        }
                    } else {
                        Menu {
                            Button {
                                isEditing = true
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }

                            Button {
                                showSubscription = true
                            } label: {
                                Label(
                                    subscriptionManager.isProSubscriber ? "iCloud Sync: On" : "Upgrade to Pro",
                                    systemImage: subscriptionManager.isProSubscriber ? "checkmark.icloud" : "icloud"
                                )
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if !isEditing {
                        Button {
                            if objectType == .category && !store.canCreateNewCategory {
                                showMaxCategoryAlert = true
                            } else {
                                showNewSheet = true
                            }
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .alert("Maximum Categories", isPresented: $showMaxCategoryAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("You can only create up to \(DittoStore.maxCategories) categories. Delete a category before creating a new one.")
            }
            .alert("Delete Category?", isPresented: .init(
                get: { categoryToDelete != nil },
                set: { if !$0 { categoryToDelete = nil } }
            )) {
                Button("Delete", role: .destructive) {
                    if let index = categoryToDelete {
                        store.removeCategory(at: index)
                        categoryToDelete = nil
                    }
                }
                Button("Cancel", role: .cancel) {
                    categoryToDelete = nil
                }
            } message: {
                Text("Deleting a category removes all of its Dittos. Are you sure?")
            }
            .sheet(isPresented: $showNewSheet) {
                NewItemView(store: store, objectType: objectType)
            }
            .sheet(item: $editTarget) { target in
                EditItemView(store: store, target: target)
            }
            .sheet(isPresented: $showSubscription) {
                SubscriptionView(subscriptionManager: subscriptionManager)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                store.loadPendingDittos()
            }
        }
    }

    @ViewBuilder
    private var listContent: some View {
        switch objectType {
        case .category:
            categoryList
        case .ditto:
            dittoList
        }
    }

    private var categoryList: some View {
        List {
            ForEach(Array(store.categories.enumerated()), id: \.element.persistentModelID) { index, cat in
                Button {
                    editTarget = .category(index: index)
                } label: {
                    HStack {
                        Text("\(cat.title) (\(cat.orderedDittos.count))")
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }
            }
            .onDelete { offsets in
                for index in offsets {
                    categoryToDelete = index
                }
            }
            .onMove { source, destination in
                if let from = source.first {
                    store.moveCategory(fromIndex: from, toIndex: destination > from ? destination - 1 : destination)
                }
            }
        }
        .listStyle(.plain)
        .environment(\.editMode, .constant(isEditing ? .active : .inactive))
    }

    private var dittoList: some View {
        List {
            ForEach(Array(store.categories.enumerated()), id: \.element.persistentModelID) { catIndex, cat in
                Section {
                    ForEach(Array(cat.orderedDittos.enumerated()), id: \.element.persistentModelID) { dittoIndex, item in
                        Button {
                            editTarget = .ditto(categoryIndex: catIndex, dittoIndex: dittoIndex)
                        } label: {
                            HStack {
                                Text(item.preview)
                                    .foregroundStyle(.primary)
                                    .lineLimit(2)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                            }
                        }
                    }
                    .onDelete { offsets in
                        for dittoIndex in offsets {
                            store.removeDitto(inCategoryAt: catIndex, at: dittoIndex)
                        }
                    }
                    .onMove { source, destination in
                        if let from = source.first {
                            store.moveDitto(
                                fromCategory: catIndex,
                                fromIndex: from,
                                toCategory: catIndex,
                                toIndex: destination > from ? destination - 1 : destination
                            )
                        }
                    }
                } header: {
                    Text(cat.title)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.plain)
        .environment(\.editMode, .constant(isEditing ? .active : .inactive))
    }
}

/// Identifies what we're editing in the edit sheet.
enum EditTarget: Identifiable {
    case category(index: Int)
    case ditto(categoryIndex: Int, dittoIndex: Int)

    var id: String {
        switch self {
        case .category(let i): return "cat-\(i)"
        case .ditto(let ci, let di): return "ditto-\(ci)-\(di)"
        }
    }
}
