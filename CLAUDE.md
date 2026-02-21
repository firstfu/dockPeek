# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

dockPeek is a native macOS Menu Bar utility that shows window thumbnail previews when hovering over Dock icons. Built with SwiftUI, AppKit, and ScreenCaptureKit. Targets macOS 26.2 with Xcode 26.2.

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

Menu Bar agent app (`LSUIElement = YES`) with no Dock icon.

### Module Dependency Flow

```
dockPeekApp (@main, SwiftUI App)
├── MenuBarExtra       → SwiftUI scene providing menu bar icon
│   └── MenuBarMenu    → SwiftUI View: Enable toggle, SettingsLink, Quit
├── Settings scene     → SettingsView
└── AppDelegate (orchestrator, via @NSApplicationDelegateAdaptor)
    ├── PermissionManager  → AXIsProcessTrustedWithOptions + 1s polling
    ├── DockWatcher        → AXUIElementCopyElementAtPosition + global mouse events, 150ms debounce
    ├── WindowManager      → CGWindowListCopyWindowInfo + SCScreenshotManager for thumbnails
    ├── PreviewPanel       → floating NSPanel(.nonactivatingPanel, .borderless) with fade animations
    └── SettingsManager    → @Observable + UserDefaults DI
```

### Data Flow

1. `DockWatcher` detects mouse near Dock via `NSEvent.addGlobalMonitorForEvents(.mouseMoved)`
2. After 150ms debounce, queries `AXUIElementCopyElementAtPosition` on the Dock process
3. Resolves AX element → running app name/PID via `NSWorkspace.shared.runningApplications`
4. `AppDelegate.handleDockHover` calls `WindowManager.fetchWindows` (async)
5. `WindowManager` filters `CGWindowListCopyWindowInfo` by PID, captures thumbnails via `SCScreenshotManager`
6. `PreviewPanel.show` creates `NSPanel` wrapping `PreviewContentView` (SwiftUI) positioned above Dock icon

### Key Patterns

- **Callback-based communication**: `DockWatcher` → `AppDelegate` via `onHoverApp`/`onHoverEnd` closures; `SettingsManager` → `AppDelegate` via `onEnabledChanged`
- **DI for testability**: `SettingsManager(defaults:)` accepts custom `UserDefaults` instance
- **`@Observable` (Observation framework)**: Used by `SettingsManager` and `PermissionManager` — not Combine
- **Window actions via AX API**: `WindowManager` handles activate (raise), close (press close button), quit via separate methods

### Xcode Project Structure

Uses `PBXFileSystemSynchronizedRootGroup` — any `.swift` file placed in `dockPeek/` or `dockPeekTests/` is automatically included in the build. No manual pbxproj edits needed for source files.

## Testing

- **Framework**: Swift Testing (`import Testing`, `@Test`, `@Suite`) — not XCTest for unit tests
- `dockPeekTests/` — `WindowInfoTests`, `SettingsManagerTests`
- `dockPeekUITests/` — UI tests using XCTest
- Tests use isolated `UserDefaults(suiteName:)` with cleanup via `removePersistentDomain`

## Swift Concurrency

- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (app target only) — all types default to `@MainActor`
- `SWIFT_APPROACHABLE_CONCURRENCY = YES` — Swift 6 concurrency safety
- Use `nonisolated` explicitly for background work
- `WindowManager.fetchWindows` is `async` — called via `Task { }` from `AppDelegate`

## Build Configuration

- App Sandbox: **disabled** (required for Accessibility API + CGWindowList access)
- Hardened Runtime: **enabled** (required for notarization)
- `LSUIElement = YES` — hides from Dock, runs as Menu Bar agent app
- Bundle ID: `com.firstfu.com.dockPeek`
- Requires **Accessibility permission** for Dock monitoring and window operations
- Requires **Screen Recording permission** for ScreenCaptureKit thumbnails
