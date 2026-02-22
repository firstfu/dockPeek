//
//  SettingsView.swift
//  dockPeek
//
//  設定視窗的 SwiftUI 視圖。提供預覽縮放比例、開機自動啟動等偏好設定的 UI 介面。
//

import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @State private var settings: SettingsManager

    init(settings: SettingsManager = SettingsManager()) {
        _settings = State(initialValue: settings)
    }

    var body: some View {
        VStack(spacing: 0) {
            // App Header
            headerSection

            // Settings Content
            Form {
                generalSection
                appearanceSection
                permissionsSection
                aboutSection
            }
            .formStyle(.grouped)
        }
        .frame(width: 420, height: 480)
        .onAppear {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate()
        }
        .onDisappear {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 6) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)
                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)

            Text("DockPeek")
                .font(.system(size: 18, weight: .bold, design: .rounded))

            Text("Window Preview for Your Dock")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }

    // MARK: - General

    private var generalSection: some View {
        Section {
            Toggle(isOn: $settings.isEnabled) {
                Label("Enable DockPeek", systemImage: "eye")
            }
            .tint(.accentColor)

            Toggle(isOn: Binding(
                get: { settings.launchAtLogin },
                set: { newValue in
                    settings.launchAtLogin = newValue
                    updateLaunchAtLogin(enabled: newValue)
                }
            )) {
                Label("Launch at Login", systemImage: "arrow.clockwise")
            }
            .tint(.accentColor)
        } header: {
            Label("General", systemImage: "gearshape")
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Label {
                    HStack {
                        Text("Preview Size")
                        Spacer()
                        Text("\(String(format: "%.1f", settings.previewScale))x")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(.quaternary, in: Capsule())
                    }
                } icon: {
                    Image(systemName: "rectangle.expand.vertical")
                }

                HStack(spacing: 8) {
                    Image(systemName: "rectangle.on.rectangle")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)

                    Slider(
                        value: $settings.previewScale,
                        in: SettingsManager.scaleRange,
                        step: 0.1
                    )

                    Image(systemName: "rectangle.on.rectangle")
                        .font(.system(size: 16))
                        .foregroundStyle(.tertiary)
                }
            }
        } header: {
            Label("Appearance", systemImage: "paintbrush")
        }
    }

    // MARK: - Permissions

    private var permissionsSection: some View {
        Section {
            PermissionRow(
                title: "Accessibility",
                icon: "hand.point.up.braille",
                description: "Required for Dock monitoring",
                isGranted: AXIsProcessTrusted(),
                action: {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                        NSWorkspace.shared.open(url)
                    }
                }
            )

            PermissionRow(
                title: "Screen Recording",
                icon: "rectangle.dashed.badge.record",
                description: "Required for window thumbnails",
                isGranted: screenRecordingGranted,
                action: {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                        NSWorkspace.shared.open(url)
                    }
                }
            )
        } header: {
            Label("Permissions", systemImage: "lock.shield")
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section {
            HStack {
                Text("Version")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(appVersion)
                    .foregroundStyle(.tertiary)
            }
            .font(.system(size: 12))
        } header: {
            Label("About", systemImage: "info.circle")
        }
    }

    // MARK: - Helpers

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private var screenRecordingGranted: Bool {
        CGPreflightScreenCaptureAccess()
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

// MARK: - Permission Row

private struct PermissionRow: View {
    let title: String
    let icon: String
    let description: String
    let isGranted: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(isGranted ? .green : .orange)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))

                Text(description)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            if isGranted {
                Label("Granted", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.green)
            } else {
                Button(action: action) {
                    Text("Grant")
                        .font(.system(size: 12, weight: .medium))
                }
                .controlSize(.small)
            }
        }
        .contentShape(Rectangle())
    }
}
