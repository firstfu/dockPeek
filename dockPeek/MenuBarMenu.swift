//
//  MenuBarMenu.swift
//  dockPeek
//

import SwiftUI

struct MenuBarMenu: View {
    @Bindable var settings: SettingsManager

    var body: some View {
        Toggle("Enable dockPeek", isOn: $settings.isEnabled)
            .toggleStyle(.checkbox)
        Divider()
        SettingsLink {
            Text("Settings...")
        }
        .keyboardShortcut(",")
        Divider()
        Button("Quit dockPeek") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
