import SwiftUI
import UniformTypeIdentifiers

/// Main list view showing either categories or dittos with a segmented control toggle.
struct DittoListView: View {

    @State var store: DittoStore
    var subscriptionManager: SubscriptionManager
    var syncSettings: SyncSettings

    @State private var objectType: DittoObjectType = .ditto
    @State private var isEditing = false
    @State private var showNewSheet = false
    @State private var editTarget: EditTarget?
    @State private var showMaxCategoryAlert = false
    @State private var categoryToDelete: Int?
    @State private var showSubscription = false
    @State private var exportItem: ExportActivityItem?
    @State private var showImporter = false
    @State private var importResult: String?
    @State private var showSyncSettings = false
    @State private var showKeyboardSetup = false

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
                    .frame(maxHeight: .infinity)
            }
            .frame(maxHeight: .infinity)
            .navigationTitle("Ditto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.dittoNavBar, for: .navigationBar)
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

                            if subscriptionManager.isProSubscriber {
                                Button {
                                    showSyncSettings = true
                                } label: {
                                    Label("Sync Settings", systemImage: "arrow.triangle.2.circlepath.icloud")
                                }

                                Button {
                                    let data = DittoImportExport.exportCSV(from: store)
                                    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("Dittos.csv")
                                    try? data.write(to: tempURL)
                                    exportItem = ExportActivityItem(url: tempURL)
                                } label: {
                                    Label("Export Dittos", systemImage: "square.and.arrow.up")
                                }

                                Button {
                                    showImporter = true
                                } label: {
                                    Label("Import Dittos", systemImage: "square.and.arrow.down")
                                }
                            }

                            Button {
                                showKeyboardSetup = true
                            } label: {
                                Label("Set Up Keyboard", systemImage: KeyboardSetupStatus.hasFullAccess ? "keyboard.fill" : "keyboard")
                            }

                            Button {
                                showSubscription = true
                            } label: {
                                Label(
                                    subscriptionManager.isProSubscriber ? "iCloud Sync" : "Enable iCloud Sync",
                                    systemImage: subscriptionManager.isProSubscriber ? "checkmark.icloud" : "icloud"
                                )
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundStyle(.white)
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
                                .foregroundStyle(.white)
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
            .sheet(isPresented: $showSyncSettings) {
                SyncSettingsView(settings: syncSettings)
            }
            .sheet(isPresented: $showKeyboardSetup) {
                KeyboardSetupView()
            }
            .sheet(item: $exportItem) { item in
                ShareSheet(items: [item.url])
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.commaSeparatedText]) { result in
                switch result {
                case .success(let url):
                    guard url.startAccessingSecurityScopedResource() else { return }
                    defer { url.stopAccessingSecurityScopedResource() }
                    if let data = try? Data(contentsOf: url) {
                        let count = (try? DittoImportExport.importCSV(data, into: store)) ?? 0
                        importResult = String(localized: "Imported \(count) new dittos.")
                    }
                case .failure:
                    importResult = String(localized: "Failed to import file.")
                }
            }
            .alert("Import Complete", isPresented: .init(
                get: { importResult != nil },
                set: { if !$0 { importResult = nil } }
            )) {
                Button("OK") { importResult = nil }
            } message: {
                Text(importResult ?? "")
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                store.loadPendingDittos()
            }
            .onAppear {
                let key = "hasShownKeyboardSetup"
                if !UserDefaults.standard.bool(forKey: key) {
                    UserDefaults.standard.set(true, forKey: key)
                    showKeyboardSetup = true
                }
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

/// Wrapper for export share sheet item.
struct ExportActivityItem: Identifiable {
    let id = UUID()
    let url: URL
}

/// UIActivityViewController wrapped for SwiftUI.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
