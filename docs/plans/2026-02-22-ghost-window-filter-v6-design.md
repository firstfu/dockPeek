# Ghost Window Filter v6 — Require Title for Minimized Windows

## Problem

Off-screen ghost/helper windows (appearing across various app types including Electron apps like Cursor, and native macOS apps) pass through the v5 filter. They show as "Untitled Window" cards with a minimized overlay and grey/blank thumbnails.

## Root Cause

The v5 filter has a fallback rule: off-screen windows with no title but a valid thumbnail are kept. This was intended for apps like Microsoft To Do. However, ScreenCaptureKit captures grey/blank thumbnails for ghost/helper windows, allowing them through.

```swift
// v5 code — thumbnail fallback allows ghost windows through
if isMinimized {
    let hasSCTitle = scWindow?.title != nil && !scWindow!.title!.isEmpty
    let hasTitle = hasCGTitle || hasSCTitle
    if !hasTitle && thumbnail == nil {  // ← ghost has thumbnail, passes
        continue
    }
}
```

## Solution: Require Title for All Minimized Windows

Remove the thumbnail fallback. All minimized windows must have a CG or SC title to be displayed.

### Filtering Rules (Updated)

| Window State | Has CG Title | Has SC Title | Has Thumbnail | Result |
|-------------|-------------|-------------|--------------|--------|
| On-screen | Yes | - | - | Keep |
| On-screen | No | - | - | **Skip** |
| Minimized | Yes | - | - | Keep |
| Minimized | No | Yes | - | Keep |
| Minimized | No | No | Yes | **Skip** (v6 change) |
| Minimized | No | No | No | **Skip** |

### Code Change

File: `dockPeek/WindowManager.swift`, `fetchWindows` method.

```swift
// Before (v5)
if isMinimized {
    let hasSCTitle = scWindow?.title != nil && !scWindow!.title!.isEmpty
    let hasTitle = hasCGTitle || hasSCTitle
    if !hasTitle && thumbnail == nil {
        continue
    }
}

// After (v6)
if isMinimized {
    let hasSCTitle = scWindow?.title != nil && !scWindow!.title!.isEmpty
    let hasTitle = hasCGTitle || hasSCTitle
    if !hasTitle {
        continue
    }
}
```

## Verification

1. Build passes
2. Unit tests pass
3. Manual: Cursor hover — no "Untitled Window" ghost card
4. Manual: Various apps with minimized windows — titled windows still display correctly

## Future Consideration

If titled ghost windows are discovered in the future, AX API validation can be added as a second layer: cross-reference off-screen windows with the app's AX window list and verify `kAXMinimizedAttribute = true`.
