//
//  SettingsManager.swift
//  dockPeek
//

import Foundation
import Observation

@Observable
final class SettingsManager {
    private let defaults: UserDefaults

    private enum Keys {
        static let isEnabled = "dockPeek.isEnabled"
        static let thumbnailWidth = "dockPeek.thumbnailWidth"
        static let launchAtLogin = "dockPeek.launchAtLogin"
    }

    var onEnabledChanged: ((Bool) -> Void)?

    var isEnabled: Bool {
        didSet {
            defaults.set(isEnabled, forKey: Keys.isEnabled)
            onEnabledChanged?(isEnabled)
        }
    }

    var thumbnailWidth: CGFloat {
        didSet {
            let clamped = min(max(thumbnailWidth, 150.0), 300.0)
            if clamped != thumbnailWidth { thumbnailWidth = clamped }
            defaults.set(clamped, forKey: Keys.thumbnailWidth)
        }
    }

    var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: Keys.launchAtLogin) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.isEnabled = defaults.object(forKey: Keys.isEnabled) as? Bool ?? true
        let rawWidth = defaults.object(forKey: Keys.thumbnailWidth) as? CGFloat ?? 200.0
        self.thumbnailWidth = min(max(rawWidth, 150.0), 300.0)
        self.launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
    }
}
