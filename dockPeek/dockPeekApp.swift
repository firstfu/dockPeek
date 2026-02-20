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
            Text("dockPeek Settings")
                .frame(width: 300, height: 200)
        }
    }
}
