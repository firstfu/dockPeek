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

    var isEnabled: Bool {
        get { defaults.object(forKey: Keys.isEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.isEnabled) }
    }

    var thumbnailWidth: CGFloat {
        get {
            let value = defaults.object(forKey: Keys.thumbnailWidth) as? CGFloat ?? 200.0
            return min(max(value, 150.0), 300.0)
        }
        set {
            let clamped = min(max(newValue, 150.0), 300.0)
            defaults.set(clamped, forKey: Keys.thumbnailWidth)
        }
    }

    var launchAtLogin: Bool {
        get { defaults.bool(forKey: Keys.launchAtLogin) }
        set { defaults.set(newValue, forKey: Keys.launchAtLogin) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }
}
