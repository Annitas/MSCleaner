//
//  CachedSimilarPhotos.swift
//  MSCleaner
//
//  Created by Anita Stashevskaya on 23.08.2025.
//

import SwiftUI
import Photos

struct CachedSimilarPhotos: Codable {
    var items: [[CachedPhotoItem]]
    let latestPhotoDate: Date
    
    init(items: [[CachedPhotoItem]], latestPhotoDate: Date) {
        self.items = items
        self.latestPhotoDate = latestPhotoDate
    }
    
    init(models: [[PhotoItem]]) {
        self.items = models.map { group in
            group.map { CachedPhotoItem(model: $0) }
        }
        let allDates = models.flatMap { $0 }.map { $0.creationDate }
        self.latestPhotoDate = allDates.max() ?? Date.distantPast
    }
}

extension CachedPhotoItem {
    func toPhotoItem() -> PhotoItem? {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
        guard let asset = assets.firstObject else { return nil }
        let uiImage = previewImageData.flatMap { UIImage(data: $0) } ?? UIImage()
        return PhotoItem(
            image: uiImage,
            creationDate: date,
            asset: asset, // TODO: remove asset, use local identifier instead
            data: sizeInBytes,
            isSelected: true,
            isBest: false
        )
    }
}
