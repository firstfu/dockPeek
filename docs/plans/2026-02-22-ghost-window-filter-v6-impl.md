# Ghost Window Filter v6 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Remove the "no title + has thumbnail" fallback for minimized windows so ghost/helper windows no longer appear as "Untitled Window" cards.

**Architecture:** Single condition change in `WindowManager.fetchWindows` — remove `&& thumbnail == nil` from the minimized window filter. This makes all minimized windows require a CG or SC title.

**Tech Stack:** Swift, CGWindowList, ScreenCaptureKit

---

### Task 1: Fix the minimized window filter

**Files:**
- Modify: `dockPeek/WindowManager.swift:80-87`

**Step 1: Apply the one-line fix**

In `dockPeek/WindowManager.swift`, change the minimized window filter from:

```swift
// Off-screen ghost/helper windows (e.g. Spark): no title + no thumbnail → skip
if isMinimized {
    let hasSCTitle = scWindow?.title != nil && !scWindow!.title!.isEmpty
    let hasTitle = hasCGTitle || hasSCTitle
    if !hasTitle && thumbnail == nil {
        continue
    }
}
```

To:

```swift
// Off-screen ghost/helper windows: no title → skip
if isMinimized {
    let hasSCTitle = scWindow?.title != nil && !scWindow!.title!.isEmpty
    let hasTitle = hasCGTitle || hasSCTitle
    if !hasTitle {
        continue
    }
}
```

The only change is removing `&& thumbnail == nil` from line 84 and updating the comment on line 80.

**Step 2: Build to verify no compilation errors**

Run: `xcodebuild -project dockPeek.xcodeproj -scheme dockPeek build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

**Step 3: Run existing unit tests**

Run: `xcodebuild -project dockPeek.xcodeproj -scheme dockPeek -only-testing:dockPeekTests test 2>&1 | tail -10`
Expected: All tests pass. No existing tests should break since `WindowManager.fetchWindows` is not unit-tested directly (it depends on CGWindowList and SCShareableContent which require live system access).

**Step 4: Commit**

```bash
git add dockPeek/WindowManager.swift
git commit -m "fix: require title for minimized windows to filter ghost cards

Remove thumbnail-only fallback for off-screen windows. All minimized
windows must now have a CG or SC title to appear in preview panel.
Fixes 'Untitled Window' ghost cards appearing across various apps."
```

### Task 2: Manual verification

**Step 1: Run the app**

Build and run dockPeek from Xcode (Cmd+R).

**Step 2: Test ghost window elimination**

Hover over Cursor (or any app that previously showed ghost cards) in the Dock.
Expected: No "Untitled Window" ghost card. Only windows with actual titles appear.

**Step 3: Test legitimate minimized windows**

1. Open any app (e.g., Safari, Finder)
2. Minimize a window to the Dock (Cmd+M)
3. Hover over that app's Dock icon
Expected: The minimized window appears with its title and minimized overlay indicator.

**Step 4: Test on-screen windows unaffected**

Hover over any app with visible windows.
Expected: Normal preview cards with titles and thumbnails, unchanged behavior.
