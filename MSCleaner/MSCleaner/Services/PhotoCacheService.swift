//
//  PhotoCacheService.swift
//  MSCleaner
//
//  Created by Anita Stashevskaya on 22.08.2025.
//

import Foundation

final class PhotosCacheService {
    private let fileManager = FileManager.default
    private let documentsURL: URL

    init() {
        documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    func save<T: Codable>(_ cache: T, for type: PhotoAlbumType) {
        let fileURL = documentsURL.appendingPathComponent(type.cacheFileName)
        do {
            let data = try JSONEncoder().encode(cache) // CHECK
            try data.write(to: fileURL)
            print("Saved cache for \(type) to \(fileURL.lastPathComponent)")
        } catch {
            print("Error saving cache for \(type): \(error.localizedDescription)")
        }
    }

    func load<T: Codable>(_ type: PhotoAlbumType, as: T.Type) -> T? {
        let fileURL = documentsURL.appendingPathComponent(type.cacheFileName)
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            print("Error loading cache for \(type): \(error.localizedDescription)")
            return nil
        }
    }

    func append<T: Codable & CacheMergeable>(_ newItems: T, for type: PhotoAlbumType) {
        var merged = newItems
        if let oldCache: T = load(type, as: T.self) {
            merged = oldCache.merged(with: newItems)
        }
        save(merged, for: type)
    }
}
