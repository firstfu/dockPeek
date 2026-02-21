//
//  WindowInfo.swift
//  dockPeek
//

import AppKit

struct WindowInfo: Identifiable {
    let id: CGWindowID
    let ownerPID: pid_t
    let title: String?
    let bounds: CGRect
    let isMinimized: Bool
    var thumbnail: NSImage?

    /// Computed alias for backward compatibility
    var windowID: CGWindowID { id }

    var displayTitle: String {
        guard let title, !title.isEmpty else { return "Untitled Window" }
        return title
    }

    init(id: CGWindowID, ownerPID: pid_t, title: String?, bounds: CGRect, isMinimized: Bool = false, thumbnail: NSImage?) {
        self.id = id
        self.ownerPID = ownerPID
        self.title = title
        self.bounds = bounds
        self.isMinimized = isMinimized
        self.thumbnail = thumbnail
    }
}
