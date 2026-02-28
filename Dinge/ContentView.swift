//
//  ContentView.swift
//  Dinge
//
//  Two-column layout: Sidebar + Main content (Things 3 style).
//  Tasks expand inline as focused card views.
//

import SwiftUI

struct ContentView: View {
    @Environment(DataStore.self) private var store
    @State private var selectedDestination: SidebarDestination? = .inbox

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selectedDestination)
        } detail: {
            if let destination = selectedDestination {
                MainContentView(destination: destination)
            } else {
                ContentUnavailableView("Select a list", systemImage: "list.bullet")
            }
        }
        .frame(minWidth: 720, minHeight: 480)
    }
}

#Preview {
    ContentView()
        .environment(DataStore())
}
