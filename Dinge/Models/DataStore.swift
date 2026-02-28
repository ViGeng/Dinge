//
//  DataStore.swift
//  Dinge
//
//  File-based persistence using JSON files.
//  Storage directory is user-configurable — placing it in iCloud Drive
//  enables seamless native synchronization.
//

import Foundation

@Observable
class DataStore {
    var tasks: [DingeTask] = []
    var projects: [DingeProject] = []
    var areas: [DingeArea] = []
    var tags: [DingeTag] = []

    private(set) var storageURL: URL

    static let defaultStorageURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Dinge", isDirectory: true)
    }()

    // MARK: - Init

    init() {
        if let bookmarked = Self.resolveBookmark() {
            storageURL = bookmarked
        } else if let saved = UserDefaults.standard.string(forKey: "storageDirectory"), !saved.isEmpty {
            storageURL = URL(fileURLWithPath: saved)
        } else {
            storageURL = Self.defaultStorageURL
        }
        ensureDirectories()
        load()
        cleanupOrphanTags()
    }

    // MARK: - Storage Path

    func setStorageURL(_ url: URL) {
        storageURL = url
        UserDefaults.standard.set(url.path, forKey: "storageDirectory")
        Self.saveBookmark(for: url)
        ensureDirectories()
        load()
    }

    func resetStorageToDefault() {
        storageURL = Self.defaultStorageURL
        UserDefaults.standard.removeObject(forKey: "storageDirectory")
        UserDefaults.standard.removeObject(forKey: "storageBookmark")
        ensureDirectories()
        load()
    }

    // MARK: - Security-Scoped Bookmarks (App Sandbox)

    private static func saveBookmark(for url: URL) {
        guard let data = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else { return }
        UserDefaults.standard.set(data, forKey: "storageBookmark")
    }

    private static func resolveBookmark() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: "storageBookmark") else { return nil }
        var stale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        ) else { return nil }
        if stale { saveBookmark(for: url) }
        guard url.startAccessingSecurityScopedResource() else { return nil }
        return url
    }

    // MARK: - File I/O

    private func ensureDirectories() {
        let fm = FileManager.default
        for dir in ["tasks", "projects", "areas", "tags"] {
            let url = storageURL.appendingPathComponent(dir, isDirectory: true)
            try? fm.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    func load() {
        tasks = loadEntities(from: "tasks")
        projects = loadEntities(from: "projects")
        areas = loadEntities(from: "areas")
        tags = loadEntities(from: "tags")
    }

    private func loadEntities<T: Decodable>(from directory: String) -> [T] {
        let dirURL = storageURL.appendingPathComponent(directory)
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: dirURL, includingPropertiesForKeys: nil
        ) else { return [] }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { url in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? decoder.decode(T.self, from: data)
            }
    }

    private let writeQueue = DispatchQueue(label: "com.vigeng.Dinge.persistence", qos: .utility)

    private func saveEntity<T: Encodable & Identifiable>(_ entity: T, to directory: String) where T.ID == UUID {
        let storageURL = self.storageURL
        writeQueue.async {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            guard let data = try? encoder.encode(entity) else { return }
            let url = storageURL
                .appendingPathComponent(directory)
                .appendingPathComponent("\(entity.id).json")
            try? data.write(to: url, options: .atomic)
        }
    }

    private func removeFile(id: UUID, from directory: String) {
        let storageURL = self.storageURL
        writeQueue.async {
            let url = storageURL
                .appendingPathComponent(directory)
                .appendingPathComponent("\(id).json")
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - Task CRUD

    func addTask(_ task: DingeTask) {
        tasks.append(task)
        saveEntity(task, to: "tasks")
    }

    func updateTask(_ task: DingeTask) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        var updated = task
        updated.modifiedAt = Date()
        tasks[index] = updated
        saveEntity(updated, to: "tasks")
    }

    func deleteTask(_ task: DingeTask) {
        tasks.removeAll { $0.id == task.id }
        removeFile(id: task.id, from: "tasks")
    }

    func toggleTaskCompletion(_ task: DingeTask) {
        var updated = task
        updated.completedAt = task.isCompleted ? nil : Date()
        updateTask(updated)
    }

    func trashTask(_ task: DingeTask) {
        var updated = task
        updated.trashedAt = Date()
        updateTask(updated)
    }

    func restoreTask(_ task: DingeTask) {
        var updated = task
        updated.trashedAt = nil
        updateTask(updated)
    }

    // MARK: - Project CRUD

    func addProject(_ project: DingeProject) {
        projects.append(project)
        saveEntity(project, to: "projects")
    }

    func updateProject(_ project: DingeProject) {
        guard let index = projects.firstIndex(where: { $0.id == project.id }) else { return }
        projects[index] = project
        saveEntity(project, to: "projects")
    }

    func deleteProject(_ project: DingeProject) {
        projects.removeAll { $0.id == project.id }
        removeFile(id: project.id, from: "projects")
        for i in tasks.indices where tasks[i].projectId == project.id {
            tasks[i].projectId = nil
            saveEntity(tasks[i], to: "tasks")
        }
    }

    // MARK: - Area CRUD

    func addArea(_ area: DingeArea) {
        areas.append(area)
        saveEntity(area, to: "areas")
    }

    func updateArea(_ area: DingeArea) {
        guard let index = areas.firstIndex(where: { $0.id == area.id }) else { return }
        areas[index] = area
        saveEntity(area, to: "areas")
    }

    func deleteArea(_ area: DingeArea) {
        areas.removeAll { $0.id == area.id }
        removeFile(id: area.id, from: "areas")
    }

    // MARK: - Tag Operations

    func findOrCreateTag(named name: String) -> DingeTag {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if let existing = tags.first(where: { $0.name.lowercased() == trimmed.lowercased() }) {
            return existing
        }
        let tag = DingeTag(name: trimmed)
        tags.append(tag)
        saveEntity(tag, to: "tags")
        return tag
    }

    func deleteTag(_ tag: DingeTag) {
        tags.removeAll { $0.id == tag.id }
        removeFile(id: tag.id, from: "tags")
        for i in tasks.indices {
            tasks[i].tagIds.removeAll { $0 == tag.id }
            saveEntity(tasks[i], to: "tasks")
        }
    }

    // MARK: - Tag Cleanup

    /// Remove tags that no task references (cleans up stale partial tags like #t, #ta).
    func cleanupOrphanTags() {
        let allReferencedIds = Set(tasks.flatMap(\.tagIds))
        let orphans = tags.filter { !allReferencedIds.contains($0.id) }
        for tag in orphans {
            tags.removeAll { $0.id == tag.id }
            removeFile(id: tag.id, from: "tags")
        }
    }

    /// Remove a specific tag from a specific task.
    func removeTagFromTask(_ tag: DingeTag, task: DingeTask) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index].tagIds.removeAll { $0 == tag.id }
        saveEntity(tasks[index], to: "tasks")
        // Clean up orphan if no other task references it
        if !tasks.contains(where: { $0.tagIds.contains(tag.id) }) {
            tags.removeAll { $0.id == tag.id }
            removeFile(id: tag.id, from: "tags")
        }
    }

    // MARK: - Queries

    func tasks(for destination: SidebarDestination) -> [DingeTask] {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!

        switch destination {
        case .inbox:
            return tasks.filter { !$0.isCompleted && !$0.isTrashed && $0.status == .inbox && $0.projectId == nil }
        case .today:
            return tasks.filter {
                !$0.isCompleted && !$0.isTrashed && ($0.scheduledDate.map { $0 < tomorrow } ?? false)
            }
        case .upcoming:
            return tasks.filter {
                !$0.isCompleted && !$0.isTrashed && (
                    ($0.scheduledDate.map { $0 >= tomorrow } ?? false) || $0.deadline != nil
                )
            }.sorted {
                ($0.scheduledDate ?? $0.deadline ?? .distantFuture) <
                ($1.scheduledDate ?? $1.deadline ?? .distantFuture)
            }
        case .anytime:
            return tasks.filter { !$0.isCompleted && !$0.isTrashed && $0.status == .anytime }
        case .someday:
            return tasks.filter { !$0.isCompleted && !$0.isTrashed && $0.status == .someday }
        case .logbook:
            return tasks.filter { $0.isCompleted && !$0.isTrashed }
                .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
        case .trash:
            return tasks.filter { $0.isTrashed }
                .sorted { ($0.trashedAt ?? .distantPast) > ($1.trashedAt ?? .distantPast) }
        case .project(let id):
            return tasks.filter { !$0.isTrashed && $0.projectId == id }
        case .area(let id):
            return tasks.filter { !$0.isTrashed && $0.areaId == id && $0.projectId == nil }
        case .tag(let id):
            return tasks.filter { !$0.isCompleted && !$0.isTrashed && $0.tagIds.contains(id) }
        }
    }

    func tagsForTask(_ task: DingeTask) -> [DingeTag] {
        task.tagIds.compactMap { tagId in tags.first { $0.id == tagId } }
    }

    /// Extract #tags from text and fully sync with the task's tagIds.
    /// Call only on deliberate save (e.g. collapse / commit), never on every keystroke.
    func syncTags(for task: inout DingeTask, from texts: [String]) {
        let pattern = try! NSRegularExpression(pattern: "#(\\w+)")
        var tagNames = Set<String>()

        for text in texts {
            let range = NSRange(text.startIndex..., in: text)
            for match in pattern.matches(in: text, range: range) {
                if let r = Range(match.range(at: 1), in: text) {
                    tagNames.insert(String(text[r]).lowercased())
                }
            }
        }

        // Rebuild tagIds from scratch so stale partial tags are dropped
        var newTagIds: [UUID] = []
        for name in tagNames {
            let tag = findOrCreateTag(named: name)
            if !newTagIds.contains(tag.id) {
                newTagIds.append(tag.id)
            }
        }
        task.tagIds = newTagIds

        // Clean up orphan tags that no task references
        let allReferencedIds = Set(tasks.flatMap(\.tagIds))
        for tag in tags where !allReferencedIds.contains(tag.id) && !newTagIds.contains(tag.id) {
            deleteTag(tag)
        }
    }
}
