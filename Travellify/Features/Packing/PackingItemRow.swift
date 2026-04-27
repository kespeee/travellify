import SwiftUI

/// Packing list item row matching Figma nodes 157:3781 / 157:3867.
/// Three render modes: existing item (unchecked / checked-strikethrough) and add-item placeholder.
/// Phase 7 (07-04, D7-24) — preserves Phase 3 interactions: tap-on-checkbox toggles isChecked,
/// tap-on-label requests inline rename via parent-owned @FocusState, strikethrough animates.
struct PackingItemRow: View {
    enum Mode {
        case item(PackingItem)
        case addPlaceholder
    }

    let mode: Mode
    var onToggle: () -> Void = {}
    var onCommitNewItem: (String) -> Void = { _ in }
    var onTapLabel: () -> Void = {}

    @State private var draftText: String = ""
    @FocusState private var isEditingDraft: Bool

    var body: some View {
        HStack(spacing: 8) {
            checkbox
            label
        }
        .frame(height: 40)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var checkbox: some View {
        switch mode {
        case .item(let item):
            Button(action: onToggle) {
                if item.isChecked {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.accentColor)
                        Image(systemName: "checkmark")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                } else {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color(.separator), lineWidth: 1)
                        }
                }
            }
            .frame(width: 24, height: 24)
            .buttonStyle(.plain)
            .animation(.easeInOut(duration: 0.2), value: item.isChecked)
        case .addPlaceholder:
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(.secondarySystemBackground))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(
                            Color(.separator),
                            style: StrokeStyle(lineWidth: 1, dash: [4, 2])
                        )
                }
                .frame(width: 24, height: 24)
        }
    }

    @ViewBuilder
    private var label: some View {
        switch mode {
        case .item(let item):
            Text(item.name)
                .font(.headline.weight(.semibold))
                .foregroundStyle(item.isChecked ? Color.secondary : Color.primary)
                .strikethrough(item.isChecked)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture { onTapLabel() }
                .animation(.easeInOut(duration: 0.2), value: item.isChecked)
        case .addPlaceholder:
            TextField("Add item", text: $draftText)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
                .focused($isEditingDraft)
                .submitLabel(.done)
                .onSubmit {
                    let trimmed = draftText.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty {
                        onCommitNewItem(trimmed)
                        draftText = ""
                        // Keep focus active for chained-add UX (Phase 3 parity).
                        isEditingDraft = true
                    } else {
                        isEditingDraft = false
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#if DEBUG
import SwiftData

#Preview("PackingItemRow states") {
    let container = try! ModelContainer(
        for: Trip.self, Destination.self, Document.self,
             PackingItem.self, PackingCategory.self, Activity.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let unchecked = PackingItem(); unchecked.name = "Passport"
    let checked = PackingItem(); checked.name = "Toothbrush"; checked.isChecked = true
    container.mainContext.insert(unchecked)
    container.mainContext.insert(checked)

    return VStack(spacing: 16) {
        PackingItemRow(mode: .item(unchecked))
        PackingItemRow(mode: .item(checked))
        PackingItemRow(mode: .addPlaceholder)
    }
    .padding()
    .modelContainer(container)
}
#endif
