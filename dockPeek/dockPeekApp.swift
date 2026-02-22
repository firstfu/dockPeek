//
//  dockPeekApp.swift
//  dockPeek
//
//  App 入口點。透過 MenuBarExtra 提供 Menu Bar 圖示與下拉選單，
//  並以 @NSApplicationDelegateAdaptor 橋接 AppDelegate 進行核心模組初始化。
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
