//
//  WindowInfo.swift
//  dockPeek
//

import AppKit

struct WindowInfo: Identifiable {
    let id: CGWindowID
    let windowID: CGWindowID
    let ownerPID: pid_t
    let title: String?
    let bounds: CGRect
    var thumbnail: NSImage?

    var displayTitle: String {
        guard let title, !title.isEmpty else { return "Untitled Window" }
        return title
    }

    init(windowID: CGWindowID, ownerPID: pid_t, title: String?, bounds: CGRect, thumbnail: NSImage?) {
        self.id = windowID
        self.windowID = windowID
        self.ownerPID = ownerPID
        self.title = title
        self.bounds = bounds
        self.thumbnail = thumbnail
    }
}
