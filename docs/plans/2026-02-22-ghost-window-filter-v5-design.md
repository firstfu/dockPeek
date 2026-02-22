# Ghost Window Filter v5 — On-Screen CG-Title-Only

## Problem

On-screen ghost/helper windows (e.g., Xcode, Sublime Text) pass through filters because SCScreenCaptureKit provides titles for them even when CGWindowList does not. The previous fix (v4) checked SC title as a "safety net" for on-screen untitled windows, which inadvertently allowed ghost windows through.

## Root Cause

```swift
// v4 code — SC lookup for on-screen untitled windows (BUG)
let scWindow: SCWindow? = (!isOnScreen || !hasCGTitle)
    ? availableContent?.windows.first(where: { $0.windowID == windowID })
    : nil
let hasSCTitle = scWindow?.title != nil && !scWindow!.title!.isEmpty
let hasTitle = hasCGTitle || hasSCTitle  // ← SC title makes ghost pass
```

Ghost window: `hasCGTitle=false`, but `hasSCTitle=true` → `hasTitle=true` → passes filter.

## Solution: On-Screen Uses CG Title Only

**Key insight**: Legitimate on-screen windows always have a CG title. Even "untitled" files have CG title "untitled". Only ghost/helper windows lack CG titles while being on-screen.

### Filtering Rules

| Window State | Has CG Title | Result |
|-------------|-------------|--------|
| On-screen | Yes | Keep |
| On-screen | No | **Skip** (ghost/helper) |
| Off-screen | Has title (CG or SC) | Keep |
| Off-screen | No title + has thumbnail | Keep (e.g., Microsoft To Do) |
| Off-screen | No title + no thumbnail | **Skip** (ghost/helper) |

### Code Change

File: `dockPeek/WindowManager.swift`, `fetchWindows` method.

- SC lookup restricted to off-screen windows only
- On-screen filter uses `hasCGTitle` instead of `hasTitle`
- Off-screen logic unchanged (SC title + thumbnail fallback)

## Verification

1. Build passes
2. Unit tests pass
3. Manual: Xcode hover — no "Untitled Window" ghost card
4. Manual: Sublime Text hover — no ghost card, "untitled" file preserved
5. Manual: Minimized Microsoft To Do — preview shows correctly
