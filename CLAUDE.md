# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

dockPeek is a native macOS Menu Bar utility that shows window thumbnail previews when hovering over Dock icons. Built with Swift 5.0, SwiftUI, AppKit, and ScreenCaptureKit. Targets macOS 26.2 with Xcode 26.2.

## Build & Test Commands

```bash
# Build
xcodebuild -project dockPeek.xcodeproj -scheme dockPeek build

# Run all tests (unit + UI)
xcodebuild -project dockPeek.xcodeproj -scheme dockPeek test

# Run only unit tests
xcodebuild -project dockPeek.xcodeproj -scheme dockPeek -only-testing:dockPeekTests test

# Run a single test suite
xcodebuild -project dockPeek.xcodeproj -scheme dockPeek -only-testing:dockPeekTests/WindowInfoTests test

# Run a single test
xcodebuild -project dockPeek.xcodeproj -scheme dockPeek -only-testing:dockPeekTests/WindowInfoTests/windowInfoProperties test
```

## Architecture

Menu Bar app (`LSUIElement = YES`) with no Dock icon. Uses `@NSApplicationDelegateAdaptor` pattern with SwiftUI `MenuBarExtra` for the menu bar icon.

### Module Dependency Flow

```
dockPeekApp (@main, SwiftUI App)
├── MenuBarExtra       → SwiftUI scene providing deterministic menu bar icon
│   └── MenuBarMenu    → SwiftUI View: Enable toggle, SettingsLink, Quit
├── Settings scene     → SettingsView
└── AppDelegate (orchestrator, via @NSApplicationDelegateAdaptor)
    ├── PermissionManager  → checks Accessibility permission, shows OnboardingView
    ├── DockWatcher        → monitors Dock hover via Accessibility API + global mouse events
    ├── WindowManager      → fetches window list (CGWindowListCopyWindowInfo) + thumbnails (ScreenCaptureKit)
    ├── PreviewPanel       → floating NSPanel wrapping PreviewContentView (SwiftUI)
    └── SettingsManager    → UserDefaults persistence (isEnabled, thumbnailWidth, launchAtLogin)
```

### Key Files

- **`dockPeekApp.swift`** — `@main` entry, `MenuBarExtra` + `Settings` scenes
- **`MenuBarMenu.swift`** — SwiftUI View for MenuBarExtra dropdown: Enable toggle, SettingsLink, Quit
- **`AppDelegate.swift`** — orchestrates Dock watching, window management, and onboarding
- **`DockWatcher.swift`** — Core: `AXUIElementCopyElementAtPosition` for Dock item detection, 150ms debounce
- **`WindowManager.swift`** — `CGWindowListCopyWindowInfo` for window list, `SCScreenshotManager` for thumbnails, AX API for window actions (activate/close/quit)
- **`PreviewPanel.swift`** — `NSPanel(.nonactivatingPanel, .borderless)` at `.floating` level with fade animations
- **`PreviewContentView.swift`** — SwiftUI: horizontal scroll of `WindowThumbnailCard` with hover close buttons
- **`PermissionManager.swift`** — `AXIsProcessTrustedWithOptions` + 1s polling timer
- **`SettingsManager.swift`** — `@Observable` with `UserDefaults` DI (testable)
- **`OnboardingView.swift`** / **`SettingsView.swift`** — SwiftUI settings and permission onboarding

### Xcode Project Structure

Uses `PBXFileSystemSynchronizedRootGroup` — any `.swift` file placed in `dockPeek/` or `dockPeekTests/` is automatically included in the build. No manual pbxproj edits needed for source files.

## Testing Structure

- `dockPeekTests/` — Unit tests using Swift Testing framework (`import Testing`, `@Test`, `@Suite`)
  - `WindowInfoTests` — model properties, displayTitle fallback
  - `SettingsManagerTests` — defaults, persistence, clamping
- `dockPeekUITests/` — UI tests using XCTest

## Swift Concurrency Settings

- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` — all types default to `@MainActor` isolation
- `SWIFT_APPROACHABLE_CONCURRENCY = YES` — Swift 6 concurrency safety model enabled
- Use `nonisolated` explicitly for background work

## Build Configuration

- App Sandbox: **disabled** (required for Accessibility API + CGWindowList access)
- Hardened Runtime: **enabled** (required for notarization)
- `LSUIElement = YES` — hides from Dock, runs as Menu Bar agent app
- Requires user-granted **Accessibility permission** for Dock monitoring and window operations
- ScreenCaptureKit used for thumbnails (may require **Screen Recording permission** on macOS 15+)
