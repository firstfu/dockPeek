//
//  SettingsManagerTests.swift
//  dockPeekTests
//
//  SettingsManager 的單元測試。使用隔離的 UserDefaults 驗證預設值、持久化及 callback 行為。
//

import Testing
import Foundation
@testable import dockPeek

@Suite("SettingsManager Tests")
struct SettingsManagerTests {
    @Test("Default values are correct")
    func defaultValues() {
        let defaults = UserDefaults(suiteName: "test-settings-defaults")!
        defaults.removePersistentDomain(forName: "test-settings-defaults")
        let manager = SettingsManager(defaults: defaults)

        #expect(manager.isEnabled == true)
        #expect(manager.previewScale == 1.0)
        #expect(manager.thumbnailWidth == 200.0)
        #expect(manager.launchAtLogin == false)
    }

    @Test("Values persist across instances")
    func persistence() {
        let suiteName = "test-settings-persistence"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let manager1 = SettingsManager(defaults: defaults)
        manager1.isEnabled = false
        manager1.previewScale = 1.5

        let manager2 = SettingsManager(defaults: defaults)
        #expect(manager2.isEnabled == false)
        #expect(manager2.previewScale == 1.5)
        #expect(manager2.thumbnailWidth == 300.0)

        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test("Preview scale clamped to valid range")
    func previewScaleClamping() {
        let defaults = UserDefaults(suiteName: "test-settings-clamp")!
        defaults.removePersistentDomain(forName: "test-settings-clamp")
        let manager = SettingsManager(defaults: defaults)

        manager.previewScale = 0.1
        #expect(manager.previewScale == 0.5)

        manager.previewScale = 5.0
        #expect(manager.previewScale == 2.0)

        manager.previewScale = 1.2
        #expect(manager.previewScale == 1.2)

        defaults.removePersistentDomain(forName: "test-settings-clamp")
    }

    @Test("Thumbnail width derived from preview scale")
    func thumbnailWidthFromScale() {
        let defaults = UserDefaults(suiteName: "test-settings-derived")!
        defaults.removePersistentDomain(forName: "test-settings-derived")
        let manager = SettingsManager(defaults: defaults)

        manager.previewScale = 0.5
        #expect(manager.thumbnailWidth == 100.0)

        manager.previewScale = 2.0
        #expect(manager.thumbnailWidth == 400.0)

        defaults.removePersistentDomain(forName: "test-settings-derived")
    }
}
