//
//  SettingsManager.swift
//  dockPeek
//
//  應用程式設定管理。使用 @Observable + UserDefaults 持久化使用者偏好設定，
//  支援 DI 注入自訂 UserDefaults 實例以利測試。
//

import Foundation
import Observation

@Observable
final class SettingsManager {
    private let defaults: UserDefaults

    private enum Keys {
        static let isEnabled = "dockPeek.isEnabled"
        static let previewScale = "dockPeek.previewScale"
        static let launchAtLogin = "dockPeek.launchAtLogin"
    }

    private static let baseThumbnailWidth: CGFloat = 200.0
    static let scaleRange: ClosedRange<CGFloat> = 0.5...2.0

    var onEnabledChanged: ((Bool) -> Void)?

    var isEnabled: Bool {
        didSet {
            defaults.set(isEnabled, forKey: Keys.isEnabled)
            onEnabledChanged?(isEnabled)
        }
    }

    var previewScale: CGFloat {
        didSet {
            let clamped = min(max(previewScale, Self.scaleRange.lowerBound), Self.scaleRange.upperBound)
            if clamped != previewScale { previewScale = clamped }
            defaults.set(clamped, forKey: Keys.previewScale)
        }
    }

    var thumbnailWidth: CGFloat {
        Self.baseThumbnailWidth * previewScale
    }

    var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: Keys.launchAtLogin) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.isEnabled = defaults.object(forKey: Keys.isEnabled) as? Bool ?? true
        let rawScale = defaults.object(forKey: Keys.previewScale) as? CGFloat ?? 1.0
        self.previewScale = min(max(rawScale, Self.scaleRange.lowerBound), Self.scaleRange.upperBound)
        self.launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
    }
}
