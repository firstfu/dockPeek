//
//  SettingsView.swift
//  dockPeek
//
//  設定視窗的 SwiftUI 視圖。提供預覽縮放比例、開機自動啟動等偏好設定的 UI 介面。
//

import SwiftUI
import ServiceManagement

// MARK: - Design Tokens

private enum Theme {
    // Accent gradient: warm amber-to-coral for a distinctive, non-generic look
    static let accentStart = Color(red: 1.0, green: 0.6, blue: 0.25)
    static let accentEnd = Color(red: 0.95, green: 0.35, blue: 0.4)
    static let accent = LinearGradient(
        colors: [accentStart, accentEnd],
        startPoint: .leading,
        endPoint: .trailing
    )

    // Header background: deep indigo-slate
    static let headerTop = Color(red: 0.12, green: 0.13, blue: 0.22)
    static let headerBottom = Color(red: 0.16, green: 0.17, blue: 0.28)

    // Status colors
    static let granted = Color(red: 0.3, green: 0.82, blue: 0.65)
    static let pending = Color(red: 1.0, green: 0.72, blue: 0.3)
}

struct SettingsView: View {
    @State private var settings: SettingsManager

    init(settings: SettingsManager = SettingsManager()) {
        _settings = State(initialValue: settings)
    }

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Form {
                generalSection
                appearanceSection
                permissionsSection
                aboutSection
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .frame(width: 500, height: 580)
        .background(Color(nsColor: .windowBackgroundColor))
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
        ZStack {
            // Deep gradient background
            LinearGradient(
                colors: [Theme.headerTop, Theme.headerBottom],
                startPoint: .top,
                endPoint: .bottom
            )

            // Subtle radial glow behind the icon
            RadialGradient(
                colors: [
                    Theme.accentStart.opacity(0.15),
                    Color.clear,
                ],
                center: .center,
                startRadius: 10,
                endRadius: 120
            )
            .offset(y: -10)

            VStack(spacing: 8) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: .black.opacity(0.35), radius: 8, y: 4)

                Text("DockPeek")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Window Preview for Your Dock")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .padding(.vertical, 24)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 140)
        .clipped()
    }

    // MARK: - General

    private var generalSection: some View {
        Section {
            settingRow(icon: "eye.fill", iconColor: Theme.accentStart) {
                Toggle("Enable DockPeek", isOn: $settings.isEnabled)
                    .tint(Theme.accentStart)
            }

            settingRow(icon: "sunrise.fill", iconColor: Theme.accentEnd) {
                Toggle("Launch at Login", isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { newValue in
                        settings.launchAtLogin = newValue
                        updateLaunchAtLogin(enabled: newValue)
                    }
                ))
                .tint(Theme.accentStart)
            }
        } header: {
            sectionHeader("General", icon: "gearshape.fill")
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    iconBadge("rectangle.expand.vertical", color: Color.purple)
                    Text("Preview Size")
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                    Text("\(String(format: "%.1f", settings.previewScale))x")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.accentStart)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(
                            Theme.accentStart.opacity(0.12),
                            in: Capsule()
                        )
                }

                HStack(spacing: 10) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)

                    Slider(
                        value: $settings.previewScale,
                        in: SettingsManager.scaleRange,
                        step: 0.1
                    )
                    .tint(Theme.accentStart)

                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            sectionHeader("Appearance", icon: "paintbrush.fill")
        }
    }

    // MARK: - Permissions

    private var permissionsSection: some View {
        Section {
            PermissionRow(
                title: "Accessibility",
                icon: "hand.raised.fill",
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
                icon: "rectangle.inset.filled.badge.record",
                description: "Required for window thumbnails",
                isGranted: screenRecordingGranted,
                action: {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                        NSWorkspace.shared.open(url)
                    }
                }
            )
        } header: {
            sectionHeader("Permissions", icon: "lock.shield.fill")
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section {
            HStack {
                iconBadge("info.circle.fill", color: .gray)
                Text("Version")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(appVersion)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Reusable Components

    private func sectionHeader(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
    }

    private func iconBadge(_ systemName: String, color: Color) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: 24, height: 24)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private func settingRow<Content: View>(
        icon: String,
        iconColor: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 10) {
            iconBadge(icon, color: iconColor)
            content()
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

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            // Icon with tinted background
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isGranted ? Theme.granted : Theme.pending)
                .frame(width: 28, height: 28)
                .background(
                    (isGranted ? Theme.granted : Theme.pending).opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))

                Text(description)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            if isGranted {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                    Text("Granted")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(Theme.granted)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Theme.granted.opacity(0.12), in: Capsule())
            } else {
                Button(action: action) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 11))
                        Text("Grant")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(
                        LinearGradient(
                            colors: [Theme.accentStart, Theme.accentEnd],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: Capsule()
                    )
                    .shadow(color: Theme.accentStart.opacity(isHovered ? 0.4 : 0.2), radius: isHovered ? 6 : 3, y: 2)
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    withAnimation(.easeOut(duration: 0.2)) {
                        isHovered = hovering
                    }
                }
            }
        }
        .contentShape(Rectangle())
    }
}
