//
//  DingeApp.swift
//  Dinge
//
//  An open-source Things 3 alternative with Markdown notes,
//  iCloud-compatible file storage, and inline #tagging.
//

import SwiftUI

@main
struct DingeApp: App {
    @State private var store = DataStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }

        Settings {
            SettingsView()
                .environment(store)
        }
    }
}
