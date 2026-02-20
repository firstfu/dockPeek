//
//  dockPeekApp.swift
//  dockPeek
//

import SwiftUI

@main
struct dockPeekApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(settings: appDelegate.settings)
        }
    }
}
