//
//  DockWatcher.swift
//  dockPeek
//

import AppKit
import CoreGraphics

final class DockWatcher {
    var onHoverApp: ((_ appPID: pid_t, _ appName: String, _ iconPosition: NSPoint) -> Void)?
    var onHoverEnd: (() -> Void)?

    private var eventMonitor: Any?
    private var dockPID: pid_t = 0
    private var dockElement: AXUIElement?
    private var debounceTimer: Timer?
    private var lastHoveredPID: pid_t = 0
    private var isActive = false

    func start() {
        guard !isActive else { return }
        isActive = true

        findDockProcess()
        startMouseMonitoring()
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
        ).first else { return }

        dockPID = dockApp.processIdentifier
        dockElement = AXUIElementCreateApplication(dockPID)
    }

    private func startMouseMonitoring() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.handleMouseMoved(event: event)
        }
    }

    private func stopMouseMonitoring() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    private func handleMouseMoved(event: NSEvent) {
        let mouseLocation = NSEvent.mouseLocation

        guard isMouseNearDock(location: mouseLocation) else {
            if lastHoveredPID != 0 {
                lastHoveredPID = 0
                debounceTimer?.invalidate()
                onHoverEnd?()
            }
            return
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
        guard let dockElement else { return }

        var elementRef: AXUIElement?
        let result = AXUIElementCopyElementAtPosition(
            dockElement,
            Float(location.x),
            Float(location.y),
            &elementRef
        )

        guard result == .success, let element = elementRef else {
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
            onHoverApp?(pid, appName, position)
        }
    }

    private func resolveRunningApp(from element: AXUIElement) -> (pid_t, String, NSPoint)? {
        var titleValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleValue) == .success,
              let title = titleValue as? String, !title.isEmpty else {
            return nil
        }

        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        var iconCenter = NSPoint.zero

        if AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue) == .success,
           AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success {
            var point = CGPoint.zero
            var size = CGSize.zero
            AXValueGetValue(positionValue as! AXValue, .cgPoint, &point)
            AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
            iconCenter = NSPoint(x: point.x + size.width / 2, y: point.y + size.height)
        }

        let runningApps = NSWorkspace.shared.runningApplications
        guard let app = runningApps.first(where: {
            $0.localizedName == title && !$0.isTerminated && $0.activationPolicy == .regular
        }) else {
            return nil
        }

        return (app.processIdentifier, title, iconCenter)
    }
}
