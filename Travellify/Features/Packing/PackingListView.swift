import SwiftUI
import SwiftData

/// Phase 7 (07-04) — Packing list redesign.
/// - Chrome-stripped List matching TripListView 07-03 (D7-21)
/// - Uncategorized items render as flat rows at the top; categories render as glass cards
/// - Toolbar `+` adds a CATEGORY (D7-23); per-card "Add item" handles items
/// - Phase 3 interactions preserved: tap-on-checkbox toggle, tap-on-label inline rename,
///   swipe-trailing Delete, long-press contextMenu (D7-24)
/// - Cross-category drag-and-drop deferred per D7-25
struct PackingListView: View {
    let tripID: PersistentIdentifier

    @Environment(\.modelContext) private var modelContext

    @Query private var categories: [PackingCategory]
    @Query private var allTripItems: [PackingItem]

    // Inline rename state (parent-owned per Phase 3 pattern)
    @State private var renamingItem: PackingItem?
    @State private var renamingCategory: PackingCategory?
    @State private var categoryRenameDraft: String = ""

    // Pending delete (existing alert flow)
    @State private var pendingDeleteCategory: PackingCategory?

    // Track which category title to focus on next render (toolbar +)
    @State private var categoryToFocusOnAppear: PackingCategory?

    @State private var errorMessage: String?

    init(tripID: PersistentIdentifier) {
        self.tripID = tripID
        _categories = Query(
            filter: #Predicate<PackingCategory> { cat in
                cat.trip?.persistentModelID == tripID
            },
            sort: \PackingCategory.sortOrder,
            order: .forward
        )
        _allTripItems = Query(
            filter: #Predicate<PackingItem> { item in
                item.trip?.persistentModelID == tripID
            }
        )
    }

    private var sortedCategories: [PackingCategory] {
        categories.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var uncategorizedItems: [PackingItem] {
        allTripItems
            .filter { $0.category == nil }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    private var trip: Trip? {
        modelContext.model(for: tripID) as? Trip
    }

    // MARK: - Mutations

    private func toggleChecked(_ item: PackingItem) {
        item.isChecked.toggle()
        save("Couldn't update item. Please try again.")
    }

    private func deleteItem(_ item: PackingItem) {
        modelContext.delete(item)
        save("Couldn't delete item. Please try again.")
    }

    private func renameItem(_ item: PackingItem, to newName: String) {
        item.name = newName
        save("Couldn't rename. Please try again.")
        renamingItem = nil
    }

    private func cancelItemRename() {
        renamingItem = nil
    }

    private func insertItem(name: String, in category: PackingCategory?) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        guard let trip else { return }

        let nextSort: Int
        if let category {
            nextSort = ((category.items ?? []).map(\.sortOrder).max() ?? -1) + 1
        } else {
            nextSort = (uncategorizedItems.map(\.sortOrder).max() ?? -1) + 1
        }
        let item = PackingItem()
        item.name = trimmed
        item.sortOrder = nextSort
        item.category = category
        item.trip = trip
        modelContext.insert(item)
        save("Couldn't add item. Please try again.")
    }

    private func addCategory() {
        guard let trip else { return }
        let nextSort = (categories.map(\.sortOrder).max() ?? -1) + 1
        let cat = PackingCategory()
        cat.name = ""
        cat.sortOrder = nextSort
        cat.trip = trip
        modelContext.insert(cat)
        save("Couldn't add category. Please try again.")
        // Trigger inline title rename for the new card.
        renamingCategory = cat
        categoryRenameDraft = ""
    }

    private func commitCategoryRename() {
        guard let cat = renamingCategory else { return }
        let trimmed = categoryRenameDraft.trimmingCharacters(in: .whitespaces)
        cat.name = trimmed.isEmpty ? "Untitled" : trimmed
        save("Couldn't rename category. Please try again.")
        renamingCategory = nil
        categoryRenameDraft = ""
    }

    private func deleteCategory(_ cat: PackingCategory) {
        modelContext.delete(cat)
        save("Couldn't delete category. Please try again.")
        pendingDeleteCategory = nil
    }

    private func save(_ failureMessage: String) {
        do { try modelContext.save() }
        catch { errorMessage = failureMessage }
    }

    /// Lazy backfill: any existing PackingItem with `.category != nil` and `.trip == nil`
    /// gets `item.trip = item.category?.trip`. Idempotent — re-running is safe.
    private func backfillItemTripIfNeeded() {
        var didChange = false
        for cat in categories {
            for item in (cat.items ?? []) {
                if item.trip == nil, let parentTrip = cat.trip {
                    item.trip = parentTrip
                    didChange = true
                }
            }
        }
        if didChange {
            save("Couldn't update packing data. Please try again.")
        }
    }

    // MARK: - Body

    var body: some View {
        listView
            .navigationTitle("Packing")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    addCategory()
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("New Category")
            }
        }
        .task {
            backfillItemTripIfNeeded()
        }
        .alert(
            pendingDeleteCategory.map { "Delete \"\($0.name)\"?" } ?? "Delete category?",
            isPresented: Binding(
                get: { pendingDeleteCategory != nil },
                set: { if !$0 { pendingDeleteCategory = nil } }
            ),
            presenting: pendingDeleteCategory
        ) { cat in
            Button("Delete", role: .destructive) { deleteCategory(cat) }
            Button("Cancel", role: .cancel) { pendingDeleteCategory = nil }
        } message: { cat in
            let itemCount = (cat.items ?? []).count
            Text("This will also delete its \(itemCount) item\(itemCount == 1 ? "" : "s") and cannot be undone.")
        }
        .alert(
            "Something went wrong",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            ),
            presenting: errorMessage
        ) { _ in
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: { msg in
            Text(msg)
        }
    }

    // MARK: - List body (split to keep Swift 6 type-checker happy)

    @ViewBuilder
    private var listView: some View {
        List {
            categoriesSection
            uncategorizedSection
        }
        .listStyle(.plain)
        .listRowSpacing(16)
        .scrollContentBackground(.hidden)
        .background(Color(.systemBackground).ignoresSafeArea())
    }

    @ViewBuilder
    private var uncategorizedSection: some View {
        VStack(spacing: 4) {
            ForEach(uncategorizedItems, id: \.id) { item in
                uncategorizedItemContent(item)
            }
            PackingItemRow(
                mode: .addPlaceholder,
                onCommitNewItem: { name in insertItem(name: name, in: nil) }
            )
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
    }

    @ViewBuilder
    private func uncategorizedItemContent(_ item: PackingItem) -> some View {
        Group {
            if renamingItem?.id == item.id {
                InlineItemRenameRow(
                    item: item,
                    onCommit: { newName in renameItem(item, to: newName) },
                    onCancel: cancelItemRename
                )
            } else {
                PackingItemRow(
                    mode: .item(item),
                    onToggle: { toggleChecked(item) },
                    onTapLabel: { renamingItem = item }
                )
            }
        }
        .contextMenu {
            Button { renamingItem = item } label: {
                Label("Rename", systemImage: "pencil")
            }
            Button(role: .destructive) { deleteItem(item) } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private var categoriesSection: some View {
        ForEach(sortedCategories, id: \.id) { category in
            categoryCardRow(category)
        }
    }

    @ViewBuilder
    private func categoryCardRow(_ category: PackingCategory) -> some View {
        Group {
            if renamingCategory?.id == category.id {
                InlineCategoryTitleCard(
                    category: category,
                    draft: $categoryRenameDraft,
                    onCommit: commitCategoryRename
                )
            } else {
                PackingCategoryCard(
                    category: category,
                    renamingItem: renamingItem,
                    onToggleItem: { item in toggleChecked(item) },
                    onTapItemLabel: { item in renamingItem = item },
                    onCommitItemRename: { item, name in renameItem(item, to: name) },
                    onCancelItemRename: cancelItemRename,
                    onCommitNewItem: { name in insertItem(name: name, in: category) }
                )
            }
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
        .contextMenu {
            Button {
                renamingCategory = category
                categoryRenameDraft = category.name
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            Button(role: .destructive) {
                if (category.items ?? []).isEmpty {
                    deleteCategory(category)
                } else {
                    pendingDeleteCategory = category
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Inline rename helpers (parent-owned per Phase 3 pattern)

/// Single uncategorized item rename row.
private struct InlineItemRenameRow: View {
    let item: PackingItem
    let onCommit: (String) -> Void
    let onCancel: () -> Void

    @State private var draft: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(item.isChecked ? Color.accentColor : Color(.secondarySystemBackground))
                .overlay {
                    if item.isChecked {
                        Image(systemName: "checkmark")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.white)
                    } else {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color(.separator), lineWidth: 1)
                    }
                }
                .frame(width: 24, height: 24)

            TextField("Item name", text: $draft)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
                .focused($focused)
                .submitLabel(.done)
                .onSubmit { commit() }
                .onAppear {
                    draft = item.name
                    focused = true
                }
                .onChange(of: focused) { _, isFocused in
                    if !isFocused { commit() }
                }
        }
        .frame(height: 40)
    }

    private func commit() {
        let trimmed = draft.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty, trimmed != item.name {
            onCommit(trimmed)
        } else {
            onCancel()
        }
    }
}

/// Glass card showing only an inline TextField for the category title — used while
/// renaming or for a freshly-created (toolbar +) category.
private struct InlineCategoryTitleCard: View {
    let category: PackingCategory
    @Binding var draft: String
    let onCommit: () -> Void

    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("Category name", text: $draft)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .focused($focused)
                .submitLabel(.done)
                .onSubmit { onCommit() }
                .onAppear {
                    if draft.isEmpty { draft = category.name }
                    focused = true
                }
                .onChange(of: focused) { _, isFocused in
                    if !isFocused { onCommit() }
                }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

#if DEBUG
#Preview("With categories") {
    NavigationStack {
        PackingListView(tripID: {
            let container = previewContainer
            let trips = (try? container.mainContext.fetch(FetchDescriptor<Trip>())) ?? []
            return (trips.first ?? Trip()).persistentModelID
        }())
    }
    .modelContainer(previewContainer)
}

#Preview("Empty") {
    let container = try! ModelContainer(
        for: Trip.self, Destination.self, Document.self,
             PackingItem.self, PackingCategory.self, Activity.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let trip = Trip()
    trip.name = "Empty trip"
    container.mainContext.insert(trip)
    return NavigationStack {
        PackingListView(tripID: trip.persistentModelID)
    }
    .modelContainer(container)
}
#endif
