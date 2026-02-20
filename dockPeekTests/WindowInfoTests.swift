//
//  WindowInfoTests.swift
//  dockPeekTests
//

import Testing
@testable import dockPeek
import AppKit

@Suite("WindowInfo Tests")
struct WindowInfoTests {
    @Test("WindowInfo stores properties correctly")
    func windowInfoProperties() {
        let image = NSImage(size: NSSize(width: 200, height: 150))
        let info = WindowInfo(
            windowID: 42,
            ownerPID: 1234,
            title: "Test Window",
            bounds: CGRect(x: 0, y: 0, width: 800, height: 600),
            thumbnail: image
        )

        #expect(info.windowID == 42)
        #expect(info.ownerPID == 1234)
        #expect(info.title == "Test Window")
        #expect(info.bounds.width == 800)
        #expect(info.thumbnail != nil)
    }

    @Test("WindowInfo with nil thumbnail")
    func windowInfoNilThumbnail() {
        let info = WindowInfo(
            windowID: 1,
            ownerPID: 100,
            title: nil,
            bounds: .zero,
            thumbnail: nil
        )

        #expect(info.title == nil)
        #expect(info.thumbnail == nil)
    }

    @Test("WindowInfo displayTitle returns title or fallback")
    func displayTitle() {
        let withTitle = WindowInfo(windowID: 1, ownerPID: 100, title: "My Window", bounds: .zero, thumbnail: nil)
        let withoutTitle = WindowInfo(windowID: 2, ownerPID: 100, title: nil, bounds: .zero, thumbnail: nil)
        let emptyTitle = WindowInfo(windowID: 3, ownerPID: 100, title: "", bounds: .zero, thumbnail: nil)

        #expect(withTitle.displayTitle == "My Window")
        #expect(withoutTitle.displayTitle == "Untitled Window")
        #expect(emptyTitle.displayTitle == "Untitled Window")
    }
}
