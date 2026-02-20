//
//  OnboardingView.swift
//  dockPeek
//

import SwiftUI

struct OnboardingView: View {
    let permissionManager: PermissionManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "hand.raised.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.blue)

            Text("dockPeek Needs Accessibility Permission")
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            Text("To detect when you hover over Dock icons, dockPeek needs Accessibility permission. This allows the app to read Dock item information.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 12) {
                Label("Open System Settings", systemImage: "1.circle.fill")
                Label("Go to Privacy & Security > Accessibility", systemImage: "2.circle.fill")
                Label("Enable dockPeek", systemImage: "3.circle.fill")
            }
            .font(.callout)

            if permissionManager.isAccessibilityGranted {
                Label("Permission Granted!", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.headline)
            }

            HStack(spacing: 12) {
                if permissionManager.isAccessibilityGranted {
                    Button("Get Started") {
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                } else {
                    Button("Open System Settings") {
                        permissionManager.openAccessibilitySettings()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .controlSize(.large)
        }
        .padding(30)
        .frame(width: 420)
    }
}
