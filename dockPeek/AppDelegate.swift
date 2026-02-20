//
//  AppDelegate.swift
//  dockPeek
//

import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    let settings = SettingsManager()
    private let permissionManager = PermissionManager()
    private let windowManager = WindowManager()
    private lazy var previewPanel = PreviewPanel(windowManager: windowManager)
    private lazy var dockWatcher = DockWatcher()
    private var onboardingWindow: NSWindow?
    private var enabledMenuItem: NSMenuItem!
    private var permissionCheckTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()

        if permissionManager.isAccessibilityGranted {
            startWatching()
        } else {
            showOnboarding()
        }
    }

    // MARK: - Menu Bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "rectangle.on.rectangle", accessibilityDescription: "dockPeek")
        }

        let menu = NSMenu()

        enabledMenuItem = NSMenuItem(title: "Enable dockPeek", action: #selector(toggleEnabled), keyEquivalent: "")
        enabledMenuItem.target = self
        enabledMenuItem.state = settings.isEnabled ? .on : .off
        menu.addItem(enabledMenuItem)

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit dockPeek", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    @objc private func toggleEnabled() {
        settings.isEnabled.toggle()
        enabledMenuItem.state = settings.isEnabled ? .on : .off

        if settings.isEnabled {
            startWatching()
        } else {
            stopWatching()
        }
    }

    @objc private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    // MARK: - Onboarding

    private func showOnboarding() {
        let view = OnboardingView(permissionManager: permissionManager)
        let hostingController = NSHostingController(rootView: view)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Welcome to dockPeek"
        window.styleMask = [.titled, .closable]
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        onboardingWindow = window
        permissionManager.startPolling()

        // Check permission state periodically
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.permissionManager.checkAccessibility()
            if self.permissionManager.isAccessibilityGranted {
                self.permissionCheckTimer?.invalidate()
                self.permissionCheckTimer = nil
                self.onboardingWindow?.close()
                self.onboardingWindow = nil
                self.startWatching()
            }
        }
    }

    // MARK: - Dock Watching

    private func startWatching() {
        guard permissionManager.isAccessibilityGranted else { return }

        dockWatcher.onHoverApp = { [weak self] pid, appName, iconPosition in
            self?.handleDockHover(pid: pid, appName: appName, iconPosition: iconPosition)
        }

        dockWatcher.onHoverEnd = { [weak self] in
            self?.previewPanel.dismiss()
        }

        dockWatcher.start()
    }

    private func stopWatching() {
        dockWatcher.stop()
        previewPanel.dismiss()
    }

    private func handleDockHover(pid: pid_t, appName: String, iconPosition: NSPoint) {
        Task {
            let windows = await windowManager.fetchWindows(
                for: pid,
                thumbnailWidth: settings.thumbnailWidth
            )

            guard !windows.isEmpty else {
                previewPanel.dismiss()
                return
            }

            previewPanel.show(
                appName: appName,
                windows: windows,
                thumbnailWidth: settings.thumbnailWidth,
                at: iconPosition
            )
        }
    }
}
