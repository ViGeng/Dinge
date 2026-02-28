//
//  SettingsView.swift
//  Dinge
//
//  Storage path configuration. Place in iCloud Drive for sync.
//

import SwiftUI
import AppKit

struct SettingsView: View {
    @Environment(DataStore.self) private var store
    @State private var storagePath = ""

    var body: some View {
        Form {
            Section("Storage Location") {
                LabeledContent("Current Path") {
                    Text(storagePath)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }

                HStack {
                    Button("Choose Directory…") { chooseDirectory() }
                    Spacer()
                    Button("Reset to Default") { resetToDefault() }
                        .foregroundStyle(.secondary)
                }

                Text("Tip: Select a folder inside iCloud Drive for seamless sync across devices.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 520, height: 220)
        .onAppear { storagePath = store.storageURL.path }
    }

    private func chooseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Select"
        panel.message = "Choose a directory for Dinge data storage"
        panel.directoryURL = URL(fileURLWithPath: storagePath)

        guard panel.runModal() == .OK, let url = panel.url else { return }
        store.setStorageURL(url)
        storagePath = url.path
    }

    private func resetToDefault() {
        store.resetStorageToDefault()
        storagePath = store.storageURL.path
    }
}
