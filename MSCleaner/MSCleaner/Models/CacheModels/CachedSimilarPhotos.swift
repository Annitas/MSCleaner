//
//  CachedSimilarPhotos.swift
//  MSCleaner
//
//  Created by Anita Stashevskaya on 23.08.2025.
//

import SwiftUI
import Photos

protocol CacheMergeable {
    func merged(with other: Self) -> Self
}

struct CachedSimilarPhotos: Codable, CacheMergeable {
    var items: [[PhotoItem]]
    let latestPhotoDate: Date
    
    init(items: [[PhotoItem]], latestPhotoDate: Date) {
        self.items = items
        self.latestPhotoDate = latestPhotoDate
    }
    
    func merged(with other: CachedSimilarPhotos) -> CachedSimilarPhotos {
        let combined = (items + other.items)
        let latest = max(latestPhotoDate, other.latestPhotoDate)
        return CachedSimilarPhotos(items: combined, latestPhotoDate: latest)
    }
}
