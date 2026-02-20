# dockPeek Window Preview App — Design Document

Date: 2026-02-20

## Overview

dockPeek is a macOS Menu Bar utility that shows window thumbnail previews when the user hovers over Dock icons. Similar to iDock (better365.cn/idock.html), it provides quick window switching without leaving the Dock.

## Requirements

- **Trigger**: Mouse hover over Dock icons
- **Core features**: Window thumbnail preview, click to switch window, close window, quit app
- **App type**: Menu Bar app (not visible in Dock)
- **Capture strategy**: Lazy on-demand capture (only when hovering)
- **Permission**: Accessibility only (no Screen Recording)
- **Settings**: Launch at login, enable/disable toggle, thumbnail size adjustment
- **Performance**: Low memory, no jank

## Architecture — Approach A: Accessibility API + CGWindowListCreateImage

Chosen for: single permission requirement, best performance for static thumbnails, stable public APIs, lowest memory footprint.

### Module Overview

```
dockPeekApp (@main, Menu Bar App)
├── AppDelegate          — Menu Bar StatusItem, lifecycle
├── DockWatcher          — Dock hover detection via Accessibility API
├── WindowManager        — Window list + thumbnail capture via CGWindowList
├── PreviewPanel         — Floating NSPanel with SwiftUI content
├── PermissionManager    — Accessibility permission check + onboarding
└── SettingsManager      — UserDefaults-based settings
```

## DockWatcher

Core module responsible for detecting which Dock icon the mouse is hovering over.

### Flow

1. Get Dock process: `NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock")`
2. Create AX element: `AXUIElementCreateApplication(dockPID)`
3. Traverse AX hierarchy: Dock AXApplication -> AXList (children) -> AXDockItem elements
4. Register global mouse move monitor: `NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved)`
5. On mouse move in Dock region: query AX element under cursor, resolve to app PID/bundleID
6. Debounce 150ms, then notify WindowManager
7. On mouse leave Dock region: trigger PreviewPanel dismiss animation

### Performance design

- **Debounce 150ms** on mouse move events
- **Early exit**: only query AX when mouse Y is near screen edge (Dock region)
- **Dock position** (bottom/left/right): detect once at launch, re-detect on `NSWorkspace` Dock preference change notification
- DockWatcher is a `class` (reference type) to avoid unnecessary copies

## WindowManager

Captures window list and thumbnails for a target app.

### Flow

1. `CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID)` — get all on-screen windows
2. Filter by `kCGWindowOwnerPID == targetPID`
3. Exclude: `kCGWindowLayer != 0`, width/height < 50, alpha == 0
4. For each valid window: `CGWindowListCreateImage(.null, .optionIncludingWindow, windowID, [.boundsIgnoreFraming, .bestResolution])`
5. Downsample to target width (default 200pt) to minimize memory
6. Execute on `DispatchQueue.global(qos: .userInitiated)`, deliver results on main thread

### Performance design

- `CGWindowListCreateImage` is GPU-accelerated
- Downsampled thumbnails: ~50-100KB each
- No background caching — capture only on demand

## PreviewPanel

Floating panel that displays window thumbnails above the hovered Dock icon.

### Implementation

- `NSPanel(styleMask: [.nonactivatingPanel, .borderless])`
- `level = .floating`, `hidesOnDeactivate = false`
- Content: `NSHostingView` wrapping SwiftUI view
- Position: centered above the hovered Dock icon

### UI layout

```
┌─────────────────────────────────────┐
│  App Name                       ✕   │  <- Title: app name + quit button
├─────────────────────────────────────┤
│ ┌───────────┐  ┌───────────┐       │
│ │           │  │           │       │  <- Thumbnail cards, horizontal scroll
│ │  Window 1 │  │  Window 2 │       │
│ │           │  │           │       │
│ │     [✕]   │  │     [✕]   │       │  <- Close button on each card
│ └───────────┘  └───────────┘       │
└─────────────────────────────────────┘
```

### Animations

- Enter: opacity 0->1 + scaleEffect 0.95->1.0, duration 0.15s
- Exit: opacity 1->0, duration 0.1s

### Actions

- Click thumbnail: `NSRunningApplication.activate()` + `AXUIElementPerformAction(kAXRaiseAction)`
- Close window: `AXUIElementPerformAction(kAXPressAction)` on window's close button
- Quit app: `NSRunningApplication.terminate()`

## PermissionManager

### Onboarding flow

1. Silent check: `AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt: false])`
2. If not authorized: show custom onboarding window with instructions
3. Open System Settings: `NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)`
4. Poll every 1s with Timer until authorized
5. On authorization: dismiss onboarding, start DockWatcher

## SettingsManager

- Storage: `@AppStorage` / `UserDefaults`
- Launch at login: `SMAppService.mainApp.register()` (macOS 13+)
- Enable/disable toggle: controls DockWatcher start/stop
- Thumbnail size: Slider 150-300pt, stored in UserDefaults

## App Lifecycle

```swift
@main
struct dockPeekApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
    // No WindowGroup -> not visible in Dock
}
```

### Menu Bar menu

- "Enable dockPeek" (toggle with checkmark)
- "Settings..." (opens Settings window)
- Separator
- "Quit dockPeek"

## File Structure

```
dockPeek/
├── App/
│   ├── dockPeekApp.swift          # @main entry point
│   └── AppDelegate.swift          # Menu Bar, lifecycle
├── Core/
│   ├── DockWatcher.swift          # Dock mouse hover detection
│   ├── WindowManager.swift        # Window list + thumbnail capture
│   └── PermissionManager.swift    # Accessibility permission management
├── UI/
│   ├── PreviewPanel.swift         # NSPanel floating panel
│   ├── PreviewContentView.swift   # SwiftUI preview content
│   ├── SettingsView.swift         # Settings page
│   └── OnboardingView.swift       # Permission onboarding page
├── Models/
│   └── WindowInfo.swift           # Window info model
├── Utilities/
│   └── SettingsManager.swift      # UserDefaults settings manager
└── Assets.xcassets/
```

## Key Technical Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Window capture API | CGWindowListCreateImage | GPU-accelerated, no extra permission needed |
| Dock hover detection | Accessibility API | Only way to identify Dock items without private API |
| Preview panel | NSPanel | Non-activating, stays floating, doesn't steal focus |
| UI framework | SwiftUI in NSHostingView | Modern, declarative, easy to maintain |
| Permission | Accessibility only | Single permission, better UX than needing Screen Recording too |
| Settings storage | UserDefaults | Simple, sufficient for few settings |
| Launch at login | SMAppService | Modern API (macOS 13+), no helper app needed |
