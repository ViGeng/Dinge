//
//  TaskRowView.swift
//  Dinge
//
//  Collapsed task row: checkbox, title, short date badge, tag icon.
//  Standard checkboxes for todos; distinct larger circle for project-level items.
//

import SwiftUI

struct TaskRowView: View {
    @Environment(DataStore.self) private var store
    let task: DingeTask

    var body: some View {
        HStack(spacing: 10) {
            // Checkbox
            Button(action: { withAnimation(.snappy) { store.toggleTaskCompletion(task) } }) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(task.isCompleted ? .green : .secondary)
                    .font(.title3)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)

            // Title
            Text(task.title)
                .strikethrough(task.isCompleted)
                .foregroundStyle(task.isCompleted ? .tertiary : .primary)
                .lineLimit(1)

            Spacer(minLength: 4)

            // Metadata badges
            HStack(spacing: 6) {
                // Check items progress
                if !task.checkItems.isEmpty {
                    let done = task.checkItems.filter(\.isCompleted).count
                    let total = task.checkItems.count
                    HStack(spacing: 2) {
                        Image(systemName: "checklist").font(.caption2)
                        Text("\(done)/\(total)")
                            .font(.caption)
                    }
                    .foregroundStyle(done == total ? .green : .secondary)
                }

                if let scheduled = task.scheduledDate {
                    shortDateBadge(scheduled, icon: "calendar", color: task.isCompleted ? .secondary : .blue)
                }
                if let deadline = task.deadline {
                    shortDateBadge(deadline, icon: "flag.fill", color: task.isCompleted ? .secondary : deadlineColor(deadline))
                }
                let taskTags = store.tagsForTask(task)
                if !taskTags.isEmpty {
                    ForEach(taskTags) { tag in
                        Text("#\(tag.name)")
                            .font(.caption2)
                            .foregroundStyle(task.isCompleted ? .secondary : Color.accentColor)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.accentColor.opacity(task.isCompleted ? 0.04 : 0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .opacity(task.isCompleted ? 0.5 : 1)
        .background(Color.clear)
    }

    private func shortDateBadge(_ date: Date, icon: String, color: Color) -> some View {
        HStack(spacing: 2) {
            Image(systemName: icon).font(.caption2)
            Text(shortDateText(date)).font(.caption)
        }
        .foregroundStyle(color)
    }

    private func shortDateText(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInTomorrow(date) { return "Tomorrow" }
        let formatter = DateFormatter()
        formatter.dateFormat = cal.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) ? "EEEE" : "EEE, MMM d"
        return formatter.string(from: date)
    }

    private func deadlineColor(_ date: Date) -> Color {
        if date < Date() { return .red }
        if Calendar.current.isDateInToday(date) { return .orange }
        return .secondary
    }
}
