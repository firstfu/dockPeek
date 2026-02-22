//
//  PermissionManager.swift
//  dockPeek
//
//  無障礙權限管理。透過 AXIsProcessTrustedWithOptions 檢查權限狀態，
//  並以 1 秒輪詢持續監測權限變更。
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
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false] as CFDictionary
        isAccessibilityGranted = AXIsProcessTrustedWithOptions(options)
    }

    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
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
