//
//  dockPeekApp.swift
//  dockPeek
//

import SwiftUI

@main
struct dockPeekApp: App {
    // Diagnostic: test NSStatusItem directly (bypassing MenuBarExtra)
    static let testStatusItem: NSStatusItem = {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "star.fill", accessibilityDescription: "test")
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Test item", action: nil, keyEquivalent: ""))
        item.menu = menu
        print("[dockPeek] NSStatusItem created directly: \(item)")
        print("[dockPeek] button: \(String(describing: item.button))")
        print("[dockPeek] button.image: \(String(describing: item.button?.image))")
        return item
    }()

    init() {
        let policyBefore = NSApplication.shared.activationPolicy()
        print("[dockPeek] activationPolicy BEFORE: \(policyBefore.rawValue) (0=regular, 1=accessory, 2=prohibited)")

        // Diagnostic: force .regular to test if LSUIElement is hiding the icon
        NSApplication.shared.setActivationPolicy(.regular)

        let policyAfter = NSApplication.shared.activationPolicy()
        print("[dockPeek] activationPolicy AFTER setActivationPolicy(.regular): \(policyAfter.rawValue)")

        _ = Self.testStatusItem
        print("[dockPeek] App.init() called")
    }

    var body: some Scene {
        let _ = print("[dockPeek] App.body evaluated")
        MenuBarExtra("dockPeek", systemImage: "gear") {
            Text("Hello from MenuBarExtra")
        }
        Settings {
            Text("Settings placeholder")
        }
    }
}
