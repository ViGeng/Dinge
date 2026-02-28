//
//  SidebarView.swift
//  Dinge
//
//  Things 3-style sidebar: smart lists, areas with nested projects.
//

import SwiftUI

struct SidebarView: View {
    @Environment(DataStore.self) private var store
    @Binding var selection: SidebarDestination?
    @State private var isAddingProject = false
    @State private var isAddingArea = false
    @State private var newName = ""
    @State private var addToArea: DingeArea?

    var body: some View {
        List(selection: $selection) {
            // Smart lists
            Section {
                sidebarRow(.inbox, "Inbox", "tray.fill", .blue)
                sidebarRow(.today, "Today", "star.fill", .yellow)
                sidebarRow(.upcoming, "Upcoming", "calendar", .red)
                sidebarRow(.anytime, "Anytime", "square.stack.fill", .teal)
                sidebarRow(.someday, "Someday", "archivebox.fill", .mint)
            }

            Section {
                sidebarRow(.logbook, "Logbook", "checkmark.square.fill", .green)
                sidebarRow(.trash, "Trash", "trash.fill", .gray)
            }

            // Areas & Projects
            if !sortedAreas.isEmpty || !standaloneProjects.isEmpty {
                Section {
                    ForEach(sortedAreas) { area in
                        DisclosureGroup {
                            // Area-level tasks row
                            sidebarRow(.area(area.id), "Tasks", "list.bullet", .secondary)

                            ForEach(projects(in: area)) { project in
                                sidebarRow(.project(project.id), project.name, "circle", projectColor(project))
                                    .contextMenu { projectContextMenu(project) }
                            }
                        } label: {
                            Label(area.name, systemImage: "folder.fill")
                                .contextMenu { areaContextMenu(area) }
                        }
                    }

                    ForEach(standaloneProjects) { project in
                        sidebarRow(.project(project.id), project.name, "circle", projectColor(project))
                            .contextMenu { projectContextMenu(project) }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            HStack {
                Menu {
                    Button("New Project", systemImage: "folder.badge.plus") {
                        addToArea = nil
                        isAddingProject = true
                    }
                    if !sortedAreas.isEmpty {
                        Menu("New Project in Area") {
                            ForEach(sortedAreas) { area in
                                Button(area.name) {
                                    addToArea = area
                                    isAddingProject = true
                                }
                            }
                        }
                    }
                    Divider()
                    Button("New Area", systemImage: "square.stack.3d.up.badge.a.fill") {
                        isAddingArea = true
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .imageScale(.large)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .sheet(isPresented: $isAddingProject) { nameSheet(title: "New Project", action: createProject) }
        .sheet(isPresented: $isAddingArea) { nameSheet(title: "New Area", action: createArea) }
    }

    // MARK: - Data

    private var standaloneProjects: [DingeProject] {
        store.projects.filter { $0.areaId == nil && !$0.isCompleted }.sorted { $0.position < $1.position }
    }

    private var sortedAreas: [DingeArea] {
        store.areas.sorted { $0.position < $1.position }
    }

    private func projects(in area: DingeArea) -> [DingeProject] {
        store.projects.filter { $0.areaId == area.id && !$0.isCompleted }.sorted { $0.position < $1.position }
    }

    private func projectColor(_ project: DingeProject) -> Color {
        .blue
    }

    // MARK: - Row

    private func sidebarRow(_ dest: SidebarDestination, _ title: String, _ icon: String, _ color: Color) -> some View {
        let count = store.tasks(for: dest).filter({ !$0.isCompleted }).count
        return Label {
            HStack {
                Text(title)
                Spacer()
                if count > 0 {
                    Text("\(count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(color)
        }
        .tag(dest)
    }

    // MARK: - Context Menus

    @ViewBuilder
    private func projectContextMenu(_ project: DingeProject) -> some View {
        Button("Complete Project") {
            var p = project; p.completedAt = Date(); store.updateProject(p)
        }
        Divider()
        Button("Delete", role: .destructive) { store.deleteProject(project) }
    }

    @ViewBuilder
    private func areaContextMenu(_ area: DingeArea) -> some View {
        Button("Delete", role: .destructive) { store.deleteArea(area) }
    }

    // MARK: - Sheets

    private func nameSheet(title: String, action: @escaping (String) -> Void) -> some View {
        VStack(spacing: 16) {
            Text(title).font(.headline)
            TextField("Name", text: $newName)
                .textFieldStyle(.roundedBorder)
                .onSubmit { submitName(action: action) }
            HStack {
                Button("Cancel") { dismissSheet() }
                Spacer()
                Button("Create") { submitName(action: action) }
                    .buttonStyle(.borderedProminent)
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
        .frame(width: 300)
    }

    private func submitName(action: (String) -> Void) {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        action(name)
        dismissSheet()
    }

    private func dismissSheet() {
        newName = ""
        isAddingProject = false
        isAddingArea = false
    }

    private func createProject(_ name: String) {
        store.addProject(DingeProject(name: name, position: store.projects.count, areaId: addToArea?.id))
    }

    private func createArea(_ name: String) {
        store.addArea(DingeArea(name: name, position: store.areas.count))
    }
}
