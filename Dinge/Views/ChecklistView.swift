//
//  ChecklistView.swift
//  Dinge
//
//  Things 3–style check items list.
//  Sits between Notes and metadata in the expanded task card.
//  Each item: toggle circle + inline-editable text.
//

import SwiftUI

struct ChecklistView: View {
    @Binding var items: [CheckItem]
    @FocusState private var focusedItemId: UUID?
    @State private var newItemTitle = ""
    @FocusState private var isNewItemFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Existing items — incomplete first, then completed
            let incomplete = items.filter { !$0.isCompleted }.sorted { $0.position < $1.position }
            let completed = items.filter { $0.isCompleted }.sorted { $0.position < $1.position }

            ForEach(incomplete) { item in
                checkItemRow(item)
            }

            // Add-item row
            addItemRow

            // Completed items at bottom, dimmed
            if !completed.isEmpty {
                ForEach(completed) { item in
                    checkItemRow(item)
                }
            }
        }
    }

    // MARK: - Check Item Row

    private func checkItemRow(_ item: CheckItem) -> some View {
        HStack(alignment: .top, spacing: 8) {
            // Toggle circle
            Button(action: { toggleItem(item) }) {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.isCompleted ? .green : .secondary)
                    .font(.system(size: 14))
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .padding(.top, 2)

            // Editable title
            TextField("", text: bindingForItem(item), axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(item.isCompleted ? .tertiary : .secondary)
                .strikethrough(item.isCompleted)
                .focused($focusedItemId, equals: item.id)
                .onSubmit { handleSubmit(after: item) }

            Spacer(minLength: 0)

            // Delete button (visible on hover would be ideal, always shown for now)
            if focusedItemId == item.id {
                Button(action: { deleteItem(item) }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
    }

    // MARK: - Add Item Row

    private var addItemRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus")
                .foregroundStyle(.tertiary)
                .font(.system(size: 12))
                .padding(.leading, 1)

            TextField("New Check Item", text: $newItemTitle, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .focused($isNewItemFocused)
                .onSubmit(addItem)
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .onTapGesture { isNewItemFocused = true }
    }

    // MARK: - Actions

    private func bindingForItem(_ item: CheckItem) -> Binding<String> {
        Binding(
            get: { items.first(where: { $0.id == item.id })?.title ?? "" },
            set: { newValue in
                if let idx = items.firstIndex(where: { $0.id == item.id }) {
                    items[idx].title = newValue
                }
            }
        )
    }

    private func toggleItem(_ item: CheckItem) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        withAnimation(.snappy(duration: 0.25)) {
            items[idx].isCompleted.toggle()
        }
    }

    private func deleteItem(_ item: CheckItem) {
        withAnimation(.snappy(duration: 0.2)) {
            items.removeAll { $0.id == item.id }
        }
    }

    private func addItem() {
        let trimmed = newItemTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let position = (items.map(\.position).max() ?? -1) + 1
        let item = CheckItem(title: trimmed, position: position)
        withAnimation(.snappy(duration: 0.2)) {
            items.append(item)
        }
        newItemTitle = ""
        // Keep focus on the add field for rapid entry
        isNewItemFocused = true
    }

    /// When pressing Enter on an existing item, add a new item below it.
    private func handleSubmit(after item: CheckItem) {
        let position = item.position + 1
        // Shift positions of items after this one
        for i in items.indices where items[i].position >= position && !items[i].isCompleted {
            items[i].position += 1
        }
        let newItem = CheckItem(position: position)
        withAnimation(.snappy(duration: 0.2)) {
            items.append(newItem)
        }
        // Focus the new item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            focusedItemId = newItem.id
        }
    }
}
