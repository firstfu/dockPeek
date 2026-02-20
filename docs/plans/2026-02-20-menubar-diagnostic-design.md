# MenuBar Icon Not Showing — Diagnostic Design

## Problem

After replacing `NSStatusItem` with SwiftUI `MenuBarExtra`, the menu bar icon still does not appear. Additionally: no console output, no onboarding window. This suggests the SwiftUI App lifecycle may not be executing properly.

## Approach: Diagnostic Logging

Add `print()` at 4 key lifecycle points to identify exactly where execution breaks:

1. `dockPeekApp.init()` — confirms SwiftUI App struct creation
2. `dockPeekApp.body` getter — confirms scene evaluation
3. `AppDelegate.init()` — confirms `@NSApplicationDelegateAdaptor` initialization
4. `AppDelegate.applicationDidFinishLaunching()` — confirms delegate lifecycle

## Expected Outcomes

| Output | Interpretation | Next Action |
|--------|---------------|-------------|
| All 4 print | MenuBarExtra created but invisible | Check LSUIElement / MenuBarExtra interaction |
| Only init, no body | Scene evaluation fails | Simplify body content |
| Only App init, no AppDelegate | @NSApplicationDelegateAdaptor fails | Remove adaptor and test |
| No output at all | Entry point not reached | Check build target / scheme |

## Files Changed

- `dockPeekApp.swift` — add init() and body print
- `AppDelegate.swift` — add init() override and print in applicationDidFinishLaunching
