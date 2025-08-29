//
//  PhotoCacheService.swift
//  MSCleaner
//
//  Created by Anita Stashevskaya on 22.08.2025.
//

import Foundation

protocol AlbumType {
    var cacheFileName: String { get }
}

protocol IdentifiableByLocalID: Codable {
    var localIdentifier: String { get }
}

final class CacheService {
    private let fileManager = FileManager.default
    private let documentsURL: URL
    
    init() {
        documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    func save<T: Codable>(_ cache: T, for type: AlbumType) {
        let fileURL = documentsURL.appendingPathComponent(type.cacheFileName)
        do {
            let data = try JSONEncoder().encode(cache)
            try data.write(to: fileURL)
            print("Saved cache for \(type) to \(fileURL.lastPathComponent)")
        } catch {
            print("Error saving cache for \(type): \(error.localizedDescription)")
        }
    }
    
    func load<T: Codable>(_ type: AlbumType, as: T.Type) -> T? {
        let fileURL = documentsURL.appendingPathComponent(type.cacheFileName)
        do {
            let data = try Data(contentsOf: fileURL)
            print("loaded cache for \(type)")
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            print("Error loading cache for \(type): \(error.localizedDescription)")
            return nil
        }
    }
    
    func deleteFromCache<T: IdentifiableByLocalID>(identifiers: [String], for type: AlbumType, as modelType: T.Type) {
        let fileURL = documentsURL.appendingPathComponent(type.cacheFileName)
        do {
            let data = try Data(contentsOf: fileURL)
            var items = try JSONDecoder().decode([T].self, from: data)
            items.removeAll { identifiers.contains($0.localIdentifier) }
            let newData = try JSONEncoder().encode(items)
            try newData.write(to: fileURL)
            print("🗑 Deleted \(identifiers.count) items from \(type.cacheFileName)")
        } catch {
            print("❌ Error deleting from cache for \(type): \(error.localizedDescription)")
        }
    }
}
