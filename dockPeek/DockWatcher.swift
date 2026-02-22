//
//  DockWatcher.swift
//  dockPeek
//
//  監測滑鼠在 Dock 上的懸停事件。透過全域 mouseMoved 事件監聽搭配
//  AXUIElementCopyElementAtPosition 查詢 Dock 圖示，以 150ms debounce
//  防止過度觸發，並將匹配到的 app 資訊透過 callback 回傳給 AppDelegate。
//

import AppKit
import CoreGraphics
import os

final class DockWatcher {
    var onHoverApp: ((_ appPID: pid_t, _ appName: String, _ iconPosition: NSPoint) -> Void)?
    var onHoverEnd: (() -> Void)?

    private let logger = Logger(subsystem: "com.firstfu.com.dockPeek", category: "DockWatcher")
    private var eventMonitor: Any?
    private var dockPID: pid_t = 0
    private var dockElement: AXUIElement?
    private var debounceTimer: Timer?
    private var lastHoveredPID: pid_t = 0
    private var isActive = false
    private var hasLoggedFirstMouseMove = false
    private var hasLoggedNearDock = false

    deinit {
        stop()
    }

    func start() {
        guard !isActive else { return }
        isActive = true
        hasLoggedFirstMouseMove = false
        hasLoggedNearDock = false

        findDockProcess()
        startMouseMonitoring()
        logger.info("DockWatcher started, dockPID=\(self.dockPID), dockElement=\(self.dockElement != nil ? "found" : "nil")")
    }

    func stop() {
        guard isActive else { return }
        isActive = false

        stopMouseMonitoring()
        debounceTimer?.invalidate()
        debounceTimer = nil
        dockElement = nil
        lastHoveredPID = 0
    }

    private func findDockProcess() {
        guard let dockApp = NSRunningApplication.runningApplications(
            withBundleIdentifier: "com.apple.dock"
        ).first else {
            logger.error("findDockProcess: Dock process not found")
            return
        }

        dockPID = dockApp.processIdentifier
        dockElement = AXUIElementCreateApplication(dockPID)
        logger.info("findDockProcess: found Dock PID=\(self.dockPID)")
    }

    private func startMouseMonitoring() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            DispatchQueue.main.async {
                self?.handleMouseMoved(event: event)
            }
        }
        logger.info("startMouseMonitoring: eventMonitor=\(self.eventMonitor != nil ? "created" : "nil")")
    }

    private func stopMouseMonitoring() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    private func handleMouseMoved(event: NSEvent) {
        let mouseLocation = NSEvent.mouseLocation

        if !hasLoggedFirstMouseMove {
            hasLoggedFirstMouseMove = true
            logger.info("handleMouseMoved: first event received at (\(mouseLocation.x, format: .fixed(precision: 0)), \(mouseLocation.y, format: .fixed(precision: 0)))")
        }

        guard isMouseNearDock(location: mouseLocation) else {
            if lastHoveredPID != 0 {
                lastHoveredPID = 0
                debounceTimer?.invalidate()
                onHoverEnd?()
            }
            return
        }

        if !hasLoggedNearDock {
            hasLoggedNearDock = true
            logger.info("handleMouseMoved: mouse entered Dock area at (\(mouseLocation.x, format: .fixed(precision: 0)), \(mouseLocation.y, format: .fixed(precision: 0)))")
        }

        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: false) { [weak self] _ in
            self?.queryDockItemAtMouse(location: mouseLocation)
        }
    }

    private func isMouseNearDock(location: NSPoint) -> Bool {
        guard let screen = NSScreen.main else { return false }
        let screenFrame = screen.frame

        let dockThreshold: CGFloat = 80

        let nearBottom = location.y < (screenFrame.minY + dockThreshold)
        let nearLeft = location.x < (screenFrame.minX + dockThreshold)
        let nearRight = location.x > (screenFrame.maxX - dockThreshold)

        return nearBottom || nearLeft || nearRight
    }

    private func queryDockItemAtMouse(location: NSPoint) {
        guard let dockElement else {
            logger.warning("queryDockItemAtMouse: dockElement is nil, skipping")
            return
        }

        // Convert Cocoa coordinates (origin bottom-left) to Quartz coordinates (origin top-left)
        guard let primaryScreenHeight = NSScreen.screens.first?.frame.height else { return }
        let quartzY = primaryScreenHeight - location.y

        var elementRef: AXUIElement?
        let result = AXUIElementCopyElementAtPosition(
            dockElement,
            Float(location.x),
            Float(quartzY),
            &elementRef
        )

        guard result == .success, let element = elementRef else {
            logger.debug("queryDockItemAtMouse: AXUIElementCopyElementAtPosition failed with \(result.rawValue)")
            if lastHoveredPID != 0 {
                lastHoveredPID = 0
                onHoverEnd?()
            }
            return
        }

        guard let appInfo = resolveRunningApp(from: element) else {
            if lastHoveredPID != 0 {
                lastHoveredPID = 0
                onHoverEnd?()
            }
            return
        }

        let (pid, appName, position) = appInfo

        if pid != lastHoveredPID {
            lastHoveredPID = pid
            logger.info("queryDockItemAtMouse: hover on '\(appName)' PID=\(pid) at (\(position.x, format: .fixed(precision: 0)), \(position.y, format: .fixed(precision: 0)))")
            onHoverApp?(pid, appName, position)
        }
    }

    private func resolveRunningApp(from element: AXUIElement) -> (pid_t, String, NSPoint)? {
        var titleValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleValue) == .success,
              let title = titleValue as? String, !title.isEmpty else {
            logger.debug("resolveRunningApp: no AX title found")
            return nil
        }

        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        var iconCenter = NSPoint.zero

        if AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue) == .success,
           AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success,
           let posRef = positionValue,
           let sizeRef = sizeValue,
           CFGetTypeID(posRef) == AXValueGetTypeID(),
           CFGetTypeID(sizeRef) == AXValueGetTypeID() {
            let posAXValue = posRef as! AXValue
            let sizeAXValue = sizeRef as! AXValue
            var point = CGPoint.zero
            var size = CGSize.zero
            AXValueGetValue(posAXValue, .cgPoint, &point)
            AXValueGetValue(sizeAXValue, .cgSize, &size)

            // AX returns Quartz coordinates (origin top-left); convert to Cocoa (origin bottom-left)
            // for PreviewPanel positioning via NSWindow.setFrameOrigin
            let primaryScreenHeight = NSScreen.screens.first?.frame.height ?? 0
            let cocoaY = primaryScreenHeight - point.y  // top of icon in Cocoa coords
            iconCenter = NSPoint(x: point.x + size.width / 2, y: cocoaY)
        }

        let runningApps = NSWorkspace.shared.runningApplications

        // Strategy 1: Match by bundle identifier via Dock item's URL attribute (most reliable)
        var urlValue: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXURLAttribute as CFString, &urlValue) == .success,
           let urlRef = urlValue {
            var appBundleID: String?
            if let url = urlRef as? URL {
                appBundleID = Bundle(url: url)?.bundleIdentifier
            } else if let urlString = urlRef as? String, let url = URL(string: urlString) {
                appBundleID = Bundle(url: url)?.bundleIdentifier
            } else if CFGetTypeID(urlRef) == CFURLGetTypeID() {
                let cfURL = urlRef as! CFURL
                let url = cfURL as URL
                appBundleID = Bundle(url: url)?.bundleIdentifier
            }
            if let bundleID = appBundleID,
               let app = runningApps.first(where: {
                   $0.bundleIdentifier == bundleID && !$0.isTerminated
               }) {
                logger.debug("resolveRunningApp: bundle ID match '\(title)' → '\(bundleID)' PID=\(app.processIdentifier)")
                return (app.processIdentifier, title, iconCenter)
            }
        }

        // Strategy 2: Exact name match for .regular apps
        if let app = runningApps.first(where: {
            $0.localizedName == title && !$0.isTerminated && $0.activationPolicy == .regular
        }) {
            logger.debug("resolveRunningApp: exact match '\(title)' → PID=\(app.processIdentifier)")
            return (app.processIdentifier, title, iconCenter)
        }

        // Strategy 3: Case-insensitive name match
        if let app = runningApps.first(where: {
            $0.localizedName?.caseInsensitiveCompare(title) == .orderedSame && !$0.isTerminated
        }) {
            logger.debug("resolveRunningApp: case-insensitive match '\(title)' → '\(app.localizedName ?? "?")' PID=\(app.processIdentifier) policy=\(app.activationPolicy.rawValue)")
            return (app.processIdentifier, title, iconCenter)
        }

        // Strategy 4: Prefix/contains match (e.g. Dock title "iTerm" vs localizedName "iTerm2")
        if let app = runningApps.first(where: {
            guard let name = $0.localizedName, !$0.isTerminated, $0.activationPolicy == .regular else { return false }
            return name.localizedCaseInsensitiveContains(title) || title.localizedCaseInsensitiveContains(name)
        }) {
            logger.debug("resolveRunningApp: contains match '\(title)' → '\(app.localizedName ?? "?")' PID=\(app.processIdentifier)")
            return (app.processIdentifier, title, iconCenter)
        }

        logger.debug("resolveRunningApp: no match for AX title '\(title)'")
        return nil
    }
}
