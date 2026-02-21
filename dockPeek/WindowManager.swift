//
//  WindowManager.swift
//  dockPeek
//

import AppKit
import CoreGraphics
import os
import ScreenCaptureKit

final class WindowManager {

    private let logger = Logger(subsystem: "com.firstfu.com.dockPeek", category: "WindowManager")

    func fetchWindows(for pid: pid_t, thumbnailWidth: CGFloat) async -> [WindowInfo] {
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            logger.warning("fetchWindows: CGWindowListCopyWindowInfo returned nil")
            return []
        }

        logger.debug("fetchWindows: PID=\(pid), total system windows=\(windowList.count)")

        // Fetch SCShareableContent once before the loop for performance
        let availableContent: SCShareableContent?
        do {
            availableContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        } catch {
            logger.warning("fetchWindows: SCShareableContent failed: \(error.localizedDescription)")
            availableContent = nil
        }

        var results: [WindowInfo] = []

        for windowDict in windowList {
            guard let ownerPID = windowDict[kCGWindowOwnerPID as String] as? pid_t,
                  ownerPID == pid,
                  let windowID = windowDict[kCGWindowNumber as String] as? CGWindowID,
                  let layer = windowDict[kCGWindowLayer as String] as? Int,
                  layer == 0 else {
                continue
            }

            guard let boundsDict = windowDict[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary),
                  bounds.width >= 50, bounds.height >= 50 else {
                continue
            }

            if let alpha = windowDict[kCGWindowAlpha as String] as? CGFloat, alpha < 0.01 {
                continue
            }

            let title = windowDict[kCGWindowName as String] as? String

            let thumbnail = await captureThumbnail(windowID: windowID, targetWidth: thumbnailWidth, availableContent: availableContent)

            let info = WindowInfo(
                id: windowID,
                ownerPID: ownerPID,
                title: title,
                bounds: bounds,
                thumbnail: thumbnail
            )
            results.append(info)
        }

        logger.info("fetchWindows: found \(results.count) window(s) for PID=\(pid)")
        return results
    }

    private func captureThumbnail(windowID: CGWindowID, targetWidth: CGFloat, availableContent: SCShareableContent?) async -> NSImage? {
        do {
            guard let availableContent else { return nil }

            guard let scWindow = availableContent.windows.first(where: { $0.windowID == windowID }) else {
                return nil
            }

            let filter = SCContentFilter(desktopIndependentWindow: scWindow)

            let originalWidth = CGFloat(scWindow.frame.width)
            let originalHeight = CGFloat(scWindow.frame.height)
            guard originalWidth > 0, originalHeight > 0 else { return nil }

            let scale = targetWidth / originalWidth
            let scaledHeight = originalHeight * scale

            let config = SCStreamConfiguration()
            config.width = Int(targetWidth)
            config.height = Int(scaledHeight)
            config.scalesToFit = true
            config.showsCursor = false

            let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)

            let size = NSSize(width: targetWidth, height: scaledHeight)
            let image = NSImage(cgImage: cgImage, size: size)
            return image
        } catch {
            return nil
        }
    }

    func activateWindow(windowInfo: WindowInfo) {
        guard let app = NSRunningApplication(processIdentifier: windowInfo.ownerPID) else { return }
        app.activate()

        let appElement = AXUIElementCreateApplication(windowInfo.ownerPID)
        var windowsValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue) == .success,
              let windows = windowsValue as? [AXUIElement] else { return }

        for window in windows {
            var titleValue: CFTypeRef?
            AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleValue)
            let axTitle = titleValue as? String

            if axTitle == windowInfo.title || windows.count == 1 {
                AXUIElementPerformAction(window, kAXRaiseAction as CFString)
                break
            }
        }
    }

    func closeWindow(windowInfo: WindowInfo) {
        let appElement = AXUIElementCreateApplication(windowInfo.ownerPID)
        var windowsValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue) == .success,
              let windows = windowsValue as? [AXUIElement] else { return }

        for window in windows {
            var titleValue: CFTypeRef?
            AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleValue)
            let axTitle = titleValue as? String

            if axTitle == windowInfo.title || windows.count == 1 {
                var closeButtonValue: CFTypeRef?
                if AXUIElementCopyAttributeValue(window, kAXCloseButtonAttribute as CFString, &closeButtonValue) == .success,
                   let closeRef = closeButtonValue,
                   CFGetTypeID(closeRef) == AXUIElementGetTypeID() {
                    let closeButton = closeRef as! AXUIElement
                    AXUIElementPerformAction(closeButton, kAXPressAction as CFString)
                }
                break
            }
        }
    }

    func quitApp(pid: pid_t) {
        guard let app = NSRunningApplication(processIdentifier: pid) else { return }
        app.terminate()
    }
}
