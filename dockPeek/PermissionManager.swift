//
//  PermissionManager.swift
//  dockPeek
//

import AppKit
import Observation

@Observable
final class PermissionManager {
    var isAccessibilityGranted: Bool = false
    private var pollTimer: Timer?

    init() {
        checkAccessibility()
    }

    func checkAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): false] as CFDictionary
        isAccessibilityGranted = AXIsProcessTrustedWithOptions(options)
    }

    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        startPolling()
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
        startPolling()
    }

    func startPolling() {
        stopPolling()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkAccessibility()
            if self?.isAccessibilityGranted == true {
                self?.stopPolling()
            }
        }
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    deinit {
        pollTimer?.invalidate()
    }
}
