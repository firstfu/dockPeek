//
//  dockPeekApp.swift
//  dockPeek
//

import SwiftUI

@main
struct dockPeekApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("dockPeek", systemImage: "rectangle.on.rectangle") {
            MenuBarMenu(settings: appDelegate.settings)
        }
        Settings {
            SettingsView(settings: appDelegate.settings)
        }
    }
}
