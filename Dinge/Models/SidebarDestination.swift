//
//  SidebarDestination.swift
//  Dinge
//

import Foundation

enum SidebarDestination: Hashable {
    case inbox
    case today
    case upcoming
    case anytime
    case someday
    case logbook
    case trash
    case project(UUID)
    case area(UUID)
    case tag(UUID)
}
