import SwiftUI
import SwiftData

struct PackingRow: View {
    let item: PackingItem
    var onToggleCheck: () -> Void
    var onCommitRename: (String) -> Void

    @State private var isEditing = false
    @State private var draft: String = ""
    @FocusState private var fieldFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggleCheck) {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.isChecked ? Color.green : Color.secondary)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.isChecked ? "Mark as unpacked" : "Mark as packed")

            if isEditing {
                TextField("Item name", text: $draft)
                    .font(.body)
                    .focused($fieldFocused)
                    .submitLabel(.done)
                    .onAppear {
                        draft = item.name
                        fieldFocused = true
                    }
                    .onSubmit { commit() }
                    .onChange(of: fieldFocused) { _, focused in
                        if !focused { commit() }
                    }
            } else {
                Text(item.name)
                    .font(.body)
                    .foregroundStyle(item.isChecked ? .secondary : .primary)
                    .strikethrough(item.isChecked, color: .secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture { isEditing = true }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.isChecked ? "\(item.name), packed" : item.name)
    }

    private func commit() {
        let trimmed = draft.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty, trimmed != item.name {
            onCommitRename(trimmed)
        }
        isEditing = false
        fieldFocused = false
    }
}

#if DEBUG
#Preview("PackingRow") {
    let container = try! ModelContainer(
        for: Trip.self, Destination.self, Document.self,
             PackingItem.self, PackingCategory.self, Activity.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let item0 = PackingItem(); item0.name = "Passport"
    let item1 = PackingItem(); item1.name = "Toothbrush"; item1.isChecked = true
    container.mainContext.insert(item0)
    container.mainContext.insert(item1)
    return List {
        PackingRow(item: item0, onToggleCheck: {}, onCommitRename: { _ in })
        PackingRow(item: item1, onToggleCheck: {}, onCommitRename: { _ in })
    }
    .modelContainer(container)
}
#endif
