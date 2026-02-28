//
//  TaskCardView.swift
//  Dinge
//
//  Expanded inline task card (Things 3 style).
//  Shows: title, notes (rendered markdown with checkboxes),
//  scheduled date, deadline, tags.
//

import SwiftUI

struct TaskCardView: View {
    @Environment(DataStore.self) private var store
    let task: DingeTask
    let onCollapse: () -> Void

    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var checkItems: [CheckItem] = []
    @State private var scheduledDate: Date?
    @State private var deadline: Date?
    @State private var showScheduledPicker = false
    @State private var showDeadlinePicker = false
    @FocusState private var isTitleFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title row: checkbox + editable title
            HStack(alignment: .top, spacing: 10) {
                Button(action: { commit(); withAnimation(.snappy) { store.toggleTaskCompletion(task); onCollapse() } }) {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(task.isCompleted ? .green : .secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)

                TextField("New To-Do", text: $title, axis: .vertical)
                    .font(.body.weight(.medium))
                    .textFieldStyle(.plain)
                    .focused($isTitleFocused)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 4)

            // Notes — always editable
            notesSection
                .padding(.horizontal, 36)
                .padding(.vertical, 4)

            // Checklist (Things 3–style)
            ChecklistView(items: $checkItems)
                .padding(.horizontal, 36)
                .padding(.vertical, 4)

            Divider().padding(.horizontal, 12).padding(.vertical, 4)

            // Metadata: dates + tags
            metadataSection
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
        }
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.06)))
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture { /* absorb taps so they don't propagate to background */ }
        .onAppear(perform: loadTask)
        .onChange(of: task.id) { loadTask() }
        .onDisappear { commit() }
        .onExitCommand(perform: commitAndCollapse)
    }

    // MARK: - Notes Section

    private var notesSection: some View {
        LiveMarkdownEditor(
            text: $notes,
            placeholder: "Notes",
            font: .systemFont(ofSize: 12),
            textColor: .secondaryLabelColor
        )
        .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
    }

    // MARK: - Metadata

    private var metadataSection: some View {
        HStack(spacing: 12) {
            // Scheduled date
            dateButton(
                date: scheduledDate,
                icon: "calendar",
                color: .blue,
                isPresented: $showScheduledPicker,
                onClear: { scheduledDate = nil }
            )
            .popover(isPresented: $showScheduledPicker) {
                DatePopover(date: $scheduledDate, onDone: { showScheduledPicker = false })
            }

            // Deadline
            dateButton(
                date: deadline,
                icon: "flag.fill",
                color: deadline.map(deadlineColor) ?? .orange,
                isPresented: $showDeadlinePicker,
                onClear: { deadline = nil }
            )
            .popover(isPresented: $showDeadlinePicker) {
                DatePopover(date: $deadline, onDone: { showDeadlinePicker = false })
            }

            Spacer()

            // Tags
            tagsDisplay
        }
    }

    @ViewBuilder
    private func dateButton(date: Date?, icon: String, color: Color, isPresented: Binding<Bool>, onClear: @escaping () -> Void) -> some View {
        if let date = date {
            HStack(spacing: 3) {
                Image(systemName: icon).font(.caption)
                Text(dateDisplayText(date))
                    .font(.caption)
                if icon == "flag.fill" {
                    Text(daysLeftText(date))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(color)
        } else {
            Button(action: { isPresented.wrappedValue = true }) {
                Image(systemName: icon)
                    .font(.callout)
                    .foregroundStyle(.secondary.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
    }

    private var tagsDisplay: some View {
        HStack(spacing: 4) {
            let taskTags = store.tagsForTask(task)
            ForEach(taskTags) { tag in
                HStack(spacing: 2) {
                    Text("#\(tag.name)")
                        .font(.caption2)
                        .foregroundStyle(Color.accentColor)
                    Button(action: { removeTag(tag) }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.accentColor.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            Button(action: {}) {
                Image(systemName: "tag")
                    .font(.callout)
                    .foregroundStyle(.secondary.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
    }

    private func removeTag(_ tag: DingeTag) {
        store.removeTagFromTask(tag, task: task)
    }

    // MARK: - Actions

    private func loadTask() {
        title = task.title
        notes = task.notes
        checkItems = task.checkItems
        scheduledDate = task.scheduledDate
        deadline = task.deadline
    }

    /// Persist local edits to store only when something actually changed.
    private func commit() {
        guard title != task.title || notes != task.notes ||
              checkItems != task.checkItems ||
              scheduledDate != task.scheduledDate || deadline != task.deadline else { return }
        var updated = task
        updated.title = title
        updated.notes = notes
        updated.checkItems = checkItems
        updated.scheduledDate = scheduledDate
        updated.deadline = deadline
        store.updateTask(updated)
    }

    /// Sync tags, persist, and collapse.
    private func commitAndCollapse() {
        var updated = task
        updated.title = title
        updated.notes = notes
        updated.checkItems = checkItems
        updated.scheduledDate = scheduledDate
        updated.deadline = deadline
        store.syncTags(for: &updated, from: [title, notes])
        store.updateTask(updated)
        onCollapse()
    }

    // MARK: - Helpers

    private func dateDisplayText(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInTomorrow(date) { return "Tomorrow" }
        let comps = cal.dateComponents([.hour, .minute], from: date)
        let hasTime = (comps.hour ?? 0) != 0 || (comps.minute ?? 0) != 0
        let formatter = DateFormatter()
        formatter.dateFormat = hasTime ? "EEE, MMM d 'at' h:mm a" : "EEE, MMM d"
        return formatter.string(from: date)
    }

    private func daysLeftText(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: date)).day ?? 0
        if days < 0 { return "\(abs(days))d overdue" }
        if days == 0 { return "today" }
        return "\(days)d left"
    }

    private func deadlineColor(_ date: Date) -> Color {
        if date < Date() { return .red }
        if Calendar.current.isDateInToday(date) { return .orange }
        return .secondary
    }
}

// MARK: - Date Popover

/// A clean date popover with "All Day" toggle and optional time picker.
struct DatePopover: View {
    @Binding var date: Date?
    var onDone: () -> Void
    @State private var allDay = true
    @State private var selectedDate = Date()
    @State private var selectedTime = Date()

    var body: some View {
        VStack(spacing: 12) {
            // Date picker (compact/inline)
            DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()

            Divider()

            // All Day toggle
            Toggle("All Day", isOn: $allDay)
                .toggleStyle(.switch)
                .padding(.horizontal, 4)

            if !allDay {
                DatePicker("Time", selection: $selectedTime, displayedComponents: .hourAndMinute)
                    .labelsHidden()
            }

            // Done button
            HStack {
                Button("Clear") {
                    date = nil
                    onDone()
                }
                .foregroundStyle(.red)
                Spacer()
                Button("Done") {
                    if allDay {
                        date = Calendar.current.startOfDay(for: selectedDate)
                    } else {
                        let cal = Calendar.current
                        let timeComps = cal.dateComponents([.hour, .minute], from: selectedTime)
                        date = cal.date(bySettingHour: timeComps.hour ?? 0,
                                        minute: timeComps.minute ?? 0,
                                        second: 0,
                                        of: selectedDate)
                    }
                    onDone()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 4)
        }
        .padding()
        .frame(width: 280)
        .onAppear {
            if let existing = date {
                selectedDate = existing
                selectedTime = existing
                let comps = Calendar.current.dateComponents([.hour, .minute], from: existing)
                allDay = (comps.hour == 0 && comps.minute == 0)
            }
        }
    }
}
