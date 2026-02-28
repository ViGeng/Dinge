//
//  MainContentView.swift
//  Dinge
//
//  Main content area showing a project/list header and its tasks.
//  Clicking a task expands it into a focused inline card.
//

import SwiftUI

struct MainContentView: View {
    @Environment(DataStore.self) private var store
    let destination: SidebarDestination
    @State private var expandedTaskId: UUID?
    @State private var newTaskTitle = ""
    @FocusState private var isNewTaskFocused: Bool

    /// Raw tasks for count / new-task positioning.
    private var tasks: [DingeTask] {
        store.tasks(for: destination)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.horizontal, 32)
                    .padding(.top, 24)
                    .padding(.bottom, 16)

                taskList
                    .padding(.horizontal, 24)

                if canAddTasks {
                    newTaskRow
                        .padding(.horizontal, 32)
                        .padding(.top, 8)
                        .padding(.bottom, 32)
                }

                Spacer(minLength: 60)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            // Clicking whitespace outside any task card collapses the expanded card
            if expandedTaskId != nil {
                withAnimation(.snappy(duration: 0.25)) { expandedTaskId = nil }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .toolbar {
            ToolbarItem {
                Button(action: focusNewTask) {
                    Label("New To-Do", systemImage: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)
                .disabled(!canAddTasks)
            }
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var header: some View {
        switch destination {
        case .project(let id):
            if let project = store.projects.first(where: { $0.id == id }) {
                ProjectHeaderView(project: project)
            }
        default:
            HStack(spacing: 10) {
                Image(systemName: destinationIcon)
                    .font(.title)
                    .foregroundStyle(destinationColor)
                Text(destinationTitle)
                    .font(.largeTitle.bold())
            }
        }
    }

    // MARK: - Task List

    /// Sorted: incomplete tasks by position, then completed tasks at the bottom.
    private var sortedTasks: [DingeTask] {
        let incomplete = tasks.filter { !$0.isCompleted }.sorted { $0.position < $1.position }
        let completed = tasks.filter { $0.isCompleted }.sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
        return incomplete + completed
    }

    private var taskList: some View {
        LazyVStack(spacing: 1) {
            ForEach(sortedTasks) { task in
                if expandedTaskId == task.id {
                    TaskCardView(task: task, onCollapse: { withAnimation(.snappy(duration: 0.25)) { expandedTaskId = nil } })
                        .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
                } else {
                    TaskRowView(task: task)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.snappy(duration: 0.25)) { expandedTaskId = task.id }
                        }
                        .transition(.opacity)
                }
            }
        }
    }

    // MARK: - New Task Row

    private var newTaskRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus.circle")
                .foregroundStyle(.secondary)
            TextField("New To-Do", text: $newTaskTitle)
                .textFieldStyle(.plain)
                .focused($isNewTaskFocused)
                .onSubmit(addTask)
        }
        .padding(.vertical, 6)
        .foregroundStyle(.secondary)
        .contentShape(Rectangle())
        .onTapGesture { isNewTaskFocused = true }
    }

    private var canAddTasks: Bool {
        switch destination {
        case .logbook, .trash: false
        default: true
        }
    }

    // MARK: - Actions

    private func focusNewTask() {
        isNewTaskFocused = true
    }

    private func addTask() {
        let trimmed = newTaskTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        var task = DingeTask(title: trimmed, position: tasks.count)

        switch destination {
        case .inbox: task.status = .inbox
        case .today:
            task.status = .anytime
            task.scheduledDate = Date()
        case .anytime: task.status = .anytime
        case .someday: task.status = .someday
        case .project(let id):
            task.projectId = id
            task.status = .anytime
        case .area(let id):
            task.areaId = id
            task.status = .anytime
        default: task.status = .inbox
        }

        store.syncTags(for: &task, from: [task.title])
        store.addTask(task)
        newTaskTitle = ""
        expandedTaskId = task.id
    }

    // MARK: - Destination metadata

    private var destinationTitle: String {
        switch destination {
        case .inbox: "Inbox"
        case .today: "Today"
        case .upcoming: "Upcoming"
        case .anytime: "Anytime"
        case .someday: "Someday"
        case .logbook: "Logbook"
        case .trash: "Trash"
        case .project(let id): store.projects.first { $0.id == id }?.name ?? "Project"
        case .area(let id): store.areas.first { $0.id == id }?.name ?? "Area"
        case .tag(let id): store.tags.first { $0.id == id }.map { "#\($0.name)" } ?? "Tag"
        }
    }

    private var destinationIcon: String {
        switch destination {
        case .inbox: "tray.fill"
        case .today: "star.fill"
        case .upcoming: "calendar"
        case .anytime: "square.stack.fill"
        case .someday: "archivebox.fill"
        case .logbook: "checkmark.square.fill"
        case .trash: "trash.fill"
        case .project: "circle"
        case .area: "folder.fill"
        case .tag: "tag.fill"
        }
    }

    private var destinationColor: Color {
        switch destination {
        case .inbox: .blue
        case .today: .yellow
        case .upcoming: .red
        case .anytime: .teal
        case .someday: .mint
        case .logbook: .green
        case .trash: .gray
        case .project: .blue
        case .area: .secondary
        case .tag: .purple
        }
    }
}

// MARK: - Project Header

struct ProjectHeaderView: View {
    @Environment(DataStore.self) private var store
    let project: DingeProject
    @State private var editedNotes: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: project.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title)
                    .foregroundStyle(project.isCompleted ? .green : .blue)
                Text(project.name)
                    .font(.largeTitle.bold())
            }

            LiveMarkdownEditor(
                text: $editedNotes,
                placeholder: "Add notes...",
                textColor: .secondaryLabelColor
            )
            .frame(maxWidth: .infinity, minHeight: 20, alignment: .leading)
        }
        .onAppear { editedNotes = project.notes }
        .onChange(of: project.id) {
            commitNotes()
            editedNotes = project.notes
        }
        .onDisappear { commitNotes() }
    }

    private func commitNotes() {
        guard editedNotes != project.notes else { return }
        var p = project
        p.notes = editedNotes
        store.updateProject(p)
    }
}
