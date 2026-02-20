# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

dockPeek is a native macOS desktop application built with Swift 5.0, SwiftUI, and SwiftData. The project targets macOS 26.2 and uses Xcode 26.2 as its build system.

## Build & Test Commands

```bash
# Build
xcodebuild -project dockPeek.xcodeproj -scheme dockPeek build

# Run all tests (unit + UI)
xcodebuild -project dockPeek.xcodeproj -scheme dockPeek test

# Run only unit tests
xcodebuild -project dockPeek.xcodeproj -scheme dockPeek -only-testing:dockPeekTests test

# Run a single test
xcodebuild -project dockPeek.xcodeproj -scheme dockPeek -only-testing:dockPeekTests/dockPeekTests/testExample test
```

## Architecture

- **Entry point**: `dockPeek/dockPeekApp.swift` — `@main` App struct, creates SwiftData `ModelContainer` and hosts `ContentView` in a `WindowGroup`
- **UI layer**: SwiftUI with `NavigationSplitView` master-detail pattern (`dockPeek/ContentView.swift`)
- **Data layer**: SwiftData models in `dockPeek/Item.swift` using `@Model` macro, queried via `@Query` and `@Environment(\.modelContext)`
- **Assets**: `dockPeek/Assets.xcassets/` — app icon, accent color

## Testing Structure

- `dockPeekTests/` — Unit tests using Apple's Swift Testing framework (`import Testing`, `@Test`)
- `dockPeekUITests/` — UI tests and launch performance tests using XCTest (`XCUIApplication`)

## Swift Concurrency Settings

- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` — all types default to `@MainActor` isolation
- `SWIFT_APPROACHABLE_CONCURRENCY = YES` — Swift 6 concurrency safety model enabled

## Security Configuration

- App Sandbox enabled
- Hardened Runtime enabled
- User-selected file access: read-only
