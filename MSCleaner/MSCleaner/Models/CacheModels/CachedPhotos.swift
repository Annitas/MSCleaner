//
//  CachedSimilarPhotos.swift
//  MSCleaner
//
//  Created by Anita Stashevskaya on 23.08.2025.
//

import Foundation

struct CachedPhotos: Codable {
    var items: [[PhotoItem]]
    let latestPhotoDate: Date
    
    init(items: [[PhotoItem]], latestPhotoDate: Date) {
        self.items = items
        self.latestPhotoDate = latestPhotoDate
    }
}
