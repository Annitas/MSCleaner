//
//  CachedPhotoItem.swift
//  MSCleaner
//
//  Created by Anita Stashevskaya on 22.08.2025.
//

import Foundation

struct CachedPhotoItem: Codable, Identifiable {
    let id: UUID
    let localIdentifier: String
    let previewImageData: Data?
    let date: Date
    let sizeInBytes: Int64
    
    init(model: PhotoItem) {
        self.id = model.id
        self.localIdentifier = model.asset.localIdentifier
        self.previewImageData = model.image.pngData()
        self.date = model.creationDate
        self.sizeInBytes = model.data
    }
}

