//
//  AppDelegate.swift
//  dockPeek
//

import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings = SettingsManager()
    let permissionManager = PermissionManager()
    private let windowManager = WindowManager()
    private lazy var previewPanel = PreviewPanel(windowManager: windowManager)
    private lazy var dockWatcher = DockWatcher()
    private var onboardingWindow: NSWindow?
    private var permissionCheckTimer: Timer?

    override init() {
        print("[dockPeek] AppDelegate.init() called")
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("[dockPeek] applicationDidFinishLaunching called")
        settings.onEnabledChanged = { [weak self] enabled in
            if enabled {
                self?.startWatching()
            } else {
                self?.stopWatching()
            }
        }

        if permissionManager.isAccessibilityGranted {
            startWatching()
        } else {
            showOnboarding()
        }
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

    func startWatching() {
        guard permissionManager.isAccessibilityGranted else { return }

        dockWatcher.onHoverApp = { [weak self] pid, appName, iconPosition in
            self?.handleDockHover(pid: pid, appName: appName, iconPosition: iconPosition)
        }

        dockWatcher.onHoverEnd = { [weak self] in
            self?.previewPanel.dismiss()
        }

        dockWatcher.start()
    }

    func stopWatching() {
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
