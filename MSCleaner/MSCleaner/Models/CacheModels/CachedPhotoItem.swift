//
//  CachedPhotoItem.swift
//  MSCleaner
//
//  Created by Anita Stashevskaya on 22.08.2025.
//

import Foundation

struct CachedPhotoItem: Codable, Identifiable {
    let id: UUID
    let previewImageData: Data   // уменьшенное превью (JPEG/PNG Data)
    let date: Date
    let sizeInBytes: Int64
}

struct CachedSimilarPhotos: Codable {
    let items: [[CachedPhotoItem]] // сгруппированные дубликаты
    let latestPhotoDate: Date      // дата самой свежей фотографии
}
