//
//  PreviewPanel.swift
//  dockPeek
//

import AppKit
import SwiftUI

final class PreviewPanel {
    private var panel: NSPanel?
    private let windowManager: WindowManager
    private var isVisible = false
    private var mouseMonitor: Any?
    private var monitorDelayItem: DispatchWorkItem?

    init(windowManager: WindowManager) {
        self.windowManager = windowManager
    }

    func show(
        appName: String,
        windows: [WindowInfo],
        thumbnailWidth: CGFloat,
        at point: NSPoint,
        onDismiss: (() -> Void)? = nil
    ) {
        dismiss()

        let content = PreviewContentView(
            appName: appName,
            windows: windows,
            thumbnailWidth: thumbnailWidth,
            onWindowClick: { [weak self] windowInfo in
                self?.windowManager.activateWindow(windowInfo: windowInfo)
                self?.dismiss()
            },
            onWindowClose: { [weak self] windowInfo in
                self?.windowManager.closeWindow(windowInfo: windowInfo)
            },
            onQuitApp: { [weak self] in
                if let pid = windows.first?.ownerPID {
                    self?.windowManager.quitApp(pid: pid)
                }
                self?.dismiss()
            }
        )

        let hostingView = NSHostingView(rootView: content)
        hostingView.setFrameSize(hostingView.fittingSize)

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: hostingView.fittingSize),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: true
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.contentView = hostingView
        panel.isMovableByWindowBackground = false

        let panelSize = hostingView.fittingSize
        let panelOrigin = NSPoint(
            x: point.x - panelSize.width / 2,
            y: point.y + 8
        )
        panel.setFrameOrigin(panelOrigin)

        if let screen = NSScreen.main {
            var frame = panel.frame
            let screenFrame = screen.visibleFrame
            if frame.maxX > screenFrame.maxX {
                frame.origin.x = screenFrame.maxX - frame.width
            }
            if frame.minX < screenFrame.minX {
                frame.origin.x = screenFrame.minX
            }
            if frame.maxY > screenFrame.maxY {
                frame.origin.y = screenFrame.maxY - frame.height
            }
            panel.setFrame(frame, display: false)
        }

        panel.alphaValue = 0
        panel.orderFront(nil)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }

        self.panel = panel
        isVisible = true
        scheduleMouseMonitor()
    }

    func dismiss() {
        guard let panel = panel, isVisible else { return }
        isVisible = false
        cancelScheduledMonitor()
        stopMouseMonitor()

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.1
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            panel.orderOut(nil)
            if self?.panel === panel {
                self?.panel = nil
            }
        })
    }

    var isPanelVisible: Bool { isVisible }

    /// Check if the mouse cursor is within or near the preview panel.
    /// Uses generous bottom padding to bridge the gap between the Dock and the panel.
    func containsMouse() -> Bool {
        guard let panel = panel, isVisible else { return false }
        let mouseLocation = NSEvent.mouseLocation
        let frame = panel.frame
        let hitFrame = NSRect(
            x: frame.origin.x - 20,
            y: frame.origin.y - 60,
            width: frame.width + 40,
            height: frame.height + 70
        )
        return hitFrame.contains(mouseLocation)
    }

    private func scheduleMouseMonitor() {
        cancelScheduledMonitor()
        let item = DispatchWorkItem { [weak self] in
            guard let self, self.isVisible else { return }
            self.startMouseMonitor()
        }
        monitorDelayItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: item)
    }

    private func cancelScheduledMonitor() {
        monitorDelayItem?.cancel()
        monitorDelayItem = nil
    }

    private func startMouseMonitor() {
        stopMouseMonitor()
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self, self.isVisible else { return }
                if !self.containsMouse() {
                    self.dismiss()
                }
            }
        }
    }

    private func stopMouseMonitor() {
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMonitor = nil
        }
    }
}
