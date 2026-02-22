//
//  MenuBarMenu.swift
//  dockPeek
//
//  Menu Bar 下拉選單視圖。提供啟用/停用切換、設定連結及退出按鈕。
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
