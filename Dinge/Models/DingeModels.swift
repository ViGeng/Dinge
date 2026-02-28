//
//  DingeModels.swift
//  Dinge
//
//  Data models for the GTD task management app.
//  Uses JSON file-based storage for iCloud Drive compatibility.
//

import Foundation

// MARK: - Task Status

enum TaskStatus: Int, Codable, CaseIterable {
    case inbox = 0
    case anytime = 1
    case someday = 2
}

// MARK: - Check Item (Things 3–style checklist)

struct CheckItem: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String = ""
    var isCompleted: Bool = false
    var position: Int = 0
}

// MARK: - Task

struct DingeTask: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String = ""
    var notes: String = ""
    var checkItems: [CheckItem] = []
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()
    var scheduledDate: Date?
    var deadline: Date?
    var completedAt: Date?
    var trashedAt: Date?
    var status: TaskStatus = .inbox
    var position: Int = 0
    var projectId: UUID?
    var areaId: UUID?
    var tagIds: [UUID] = []

    var isCompleted: Bool { completedAt != nil }
    var isTrashed: Bool { trashedAt != nil }
}

// MARK: - Project

struct DingeProject: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String = ""
    var notes: String = ""
    var createdAt: Date = Date()
    var completedAt: Date?
    var position: Int = 0
    var areaId: UUID?

    var isCompleted: Bool { completedAt != nil }
}

// MARK: - Area

struct DingeArea: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String = ""
    var position: Int = 0
}

// MARK: - Tag

struct DingeTag: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String = ""
}
