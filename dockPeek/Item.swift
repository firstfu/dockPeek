//
//  Item.swift
//  dockPeek
//
//  Created by firstfu on 2026/2/20.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
