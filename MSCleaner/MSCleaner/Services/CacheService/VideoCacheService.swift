//
//  VideoCacheService.swift
//  MSCleaner
//
//  Created by Anita Stashevskaya on 25.08.2025.
//

import Foundation

final class VideoCacheService {
    private let fileManager = FileManager.default
    private let documentsURL: URL
    
    init() {
        documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    func save<T: Codable>(_ cache: T, for type: VideoAlbumType) {
        let fileURL = documentsURL.appendingPathComponent(type.cacheFileName)
        do {
            let data = try JSONEncoder().encode(cache) // CHECK
            try data.write(to: fileURL)
            print("Saved cache for \(type) to \(fileURL.lastPathComponent)")
        } catch {
            print("Error saving cache for \(type): \(error.localizedDescription)")
        }
    }
    
    func load<T: Codable>(_ type: VideoAlbumType, as: T.Type) -> T? {
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
}
