//
//  CachedVideos.swift
//  MSCleaner
//
//  Created by Anita Stashevskaya on 25.08.2025.
//

import Foundation

struct CachedVideos: Codable {
    var items: [[VideoItem]]
    let latestVideoDate: Date
    
    init(items: [[VideoItem]], latestVideoDate: Date) {
        self.items = items
        self.latestVideoDate = latestVideoDate
    }
}
