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
    var thumbnail: NSImage?

    /// Computed alias for backward compatibility
    var windowID: CGWindowID { id }

    var displayTitle: String {
        guard let title, !title.isEmpty else { return "Untitled Window" }
        return title
    }

    init(id: CGWindowID, ownerPID: pid_t, title: String?, bounds: CGRect, thumbnail: NSImage?) {
        self.id = id
        self.ownerPID = ownerPID
        self.title = title
        self.bounds = bounds
        self.thumbnail = thumbnail
    }
}
