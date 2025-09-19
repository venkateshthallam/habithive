//
//  Item.swift
//  HabitHive
//
//  Created by Venkatesh Thallam on 9/14/25.
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
