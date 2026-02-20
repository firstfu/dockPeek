//
//  SettingsView.swift
//  dockPeek
//

import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @State private var settings: SettingsManager

    init(settings: SettingsManager = SettingsManager()) {
        _settings = State(initialValue: settings)
    }

    var body: some View {
        Form {
            Section("General") {
                Toggle("Enable dockPeek", isOn: $settings.isEnabled)

                Toggle("Launch at Login", isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { newValue in
                        settings.launchAtLogin = newValue
                        updateLaunchAtLogin(enabled: newValue)
                    }
                ))
            }

            Section("Appearance") {
                VStack(alignment: .leading) {
                    Text("Thumbnail Width: \(Int(settings.thumbnailWidth))pt")
                    Slider(value: $settings.thumbnailWidth, in: 150...300, step: 10)
                }
            }

            Section("Permissions") {
                HStack {
                    Text("Accessibility")
                    Spacer()
                    if AXIsProcessTrusted() {
                        Label("Granted", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button("Grant Permission") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 350, height: 280)
    }

    private func updateLaunchAtLogin(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            settings.launchAtLogin = !enabled
        }
    }
}
