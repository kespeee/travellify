import SwiftUI

/// Glass card wrapping a packing category — title at top, items list, add-item row.
/// Phase 7 (07-04, D7-16/D7-24) — `.glassEffect(.clear, in: RoundedRectangle(24))`.
/// Long-press → contextMenu (Rename / Delete) is attached at the parent List row level,
/// not inside this view, so the gesture doesn't race with inner buttons.
struct PackingCategoryCard: View {
    let category: PackingCategory
    let renamingItem: PackingItem?
    var onToggleItem: (PackingItem) -> Void = { _ in }
    var onTapItemLabel: (PackingItem) -> Void = { _ in }
    var onCommitItemRename: (PackingItem, String) -> Void = { _, _ in }
    var onCancelItemRename: () -> Void = {}
    var onCommitNewItem: (String) -> Void = { _ in }

    private var sortedItems: [PackingItem] {
        (category.items ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(category.name.isEmpty ? "Untitled" : category.name)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 4) {
                ForEach(sortedItems, id: \.id) { item in
                    if renamingItem?.id == item.id {
                        InlineRenameRow(
                            item: item,
                            onCommit: { newName in onCommitItemRename(item, newName) },
                            onCancel: onCancelItemRename
                        )
                        .frame(height: 40)
                    } else {
                        PackingItemRow(
                            mode: .item(item),
                            onToggle: { onToggleItem(item) },
                            onTapLabel: { onTapItemLabel(item) }
                        )
                    }
                }
                PackingItemRow(
                    mode: .addPlaceholder,
                    onCommitNewItem: { name in onCommitNewItem(name) }
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

/// Inline rename row used when an item's label is tapped (Phase 3 parity, parent-driven).
private struct InlineRenameRow: View {
    let item: PackingItem
    let onCommit: (String) -> Void
    let onCancel: () -> Void

    @State private var draft: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 8) {
            // Mirror the unchecked checkbox visual so the row aligns with siblings.
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
        .contentShape(Rectangle())
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

#if DEBUG
import SwiftData

#Preview("PackingCategoryCard") {
    let container = try! ModelContainer(
        for: Trip.self, Destination.self, Document.self,
             PackingItem.self, PackingCategory.self, Activity.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let cat = PackingCategory()
    cat.name = "Clothes"
    let item1 = PackingItem(); item1.name = "T-shirts"; item1.sortOrder = 0; item1.category = cat
    let item2 = PackingItem(); item2.name = "Jeans"; item2.isChecked = true; item2.sortOrder = 1; item2.category = cat
    container.mainContext.insert(cat)
    container.mainContext.insert(item1)
    container.mainContext.insert(item2)

    return PackingCategoryCard(category: cat, renamingItem: nil)
        .padding()
        .background(Color(.systemBackground))
        .modelContainer(container)
}
#endif
