//
//  AppDelegate.swift
//  dockPeek
//
//  應用程式主協調器。負責初始化並串接 DockWatcher、WindowManager、
//  PreviewPanel、PermissionManager、SettingsManager 等模組，
//  處理 Dock hover 事件與 preview panel 的顯示/消失邏輯。
//

import AppKit
import os
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings = SettingsManager()
    let permissionManager = PermissionManager()
    private let logger = Logger(subsystem: "com.firstfu.com.dockPeek", category: "AppDelegate")
    private let windowManager = WindowManager()
    private lazy var previewPanel = PreviewPanel(windowManager: windowManager)
    private lazy var dockWatcher = DockWatcher()
    private var onboardingWindow: NSWindow?
    private var permissionCheckTimer: Timer?
    private var dismissWorkItem: DispatchWorkItem?

    override init() {
        super.init()
        logger.info("AppDelegate.init() called")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.info("applicationDidFinishLaunching: accessibility=\(self.permissionManager.isAccessibilityGranted), enabled=\(self.settings.isEnabled)")
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
        guard permissionManager.isAccessibilityGranted else {
            logger.warning("startWatching: accessibility not granted, aborting")
            return
        }

        logger.info("startWatching: setting up DockWatcher callbacks and starting")

        dockWatcher.onHoverApp = { [weak self] pid, appName, iconPosition in
            self?.dismissWorkItem?.cancel()
            self?.dismissWorkItem = nil
            self?.handleDockHover(pid: pid, appName: appName, iconPosition: iconPosition)
        }

        dockWatcher.onHoverEnd = { [weak self] in
            guard let self else { return }
            self.dismissWorkItem?.cancel()
            let item = DispatchWorkItem { [weak self] in
                guard let self else { return }
                if self.previewPanel.containsMouse() { return }
                self.previewPanel.dismiss()
            }
            self.dismissWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: item)
        }

        dockWatcher.start()
    }

    func stopWatching() {
        dockWatcher.stop()
        dismissWorkItem?.cancel()
        dismissWorkItem = nil
        previewPanel.dismiss()
    }

    private func handleDockHover(pid: pid_t, appName: String, iconPosition: NSPoint) {
        logger.info("handleDockHover: '\(appName)' PID=\(pid)")
        Task {
            let windows = await windowManager.fetchWindows(
                for: pid,
                thumbnailWidth: settings.thumbnailWidth
            )

            guard !windows.isEmpty else {
                logger.debug("handleDockHover: no windows for '\(appName)', dismissing")
                previewPanel.dismiss()
                return
            }

            logger.info("handleDockHover: showing \(windows.count) window(s) for '\(appName)'")
            dismissWorkItem?.cancel()
            dismissWorkItem = nil
            previewPanel.show(
                appName: appName,
                windows: windows,
                thumbnailWidth: settings.thumbnailWidth,
                previewScale: settings.previewScale,
                at: iconPosition
            )
        }
    }
}
