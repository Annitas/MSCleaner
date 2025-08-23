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
    private let fileName = "cleanerScreenshotCaches.json"
    
    init() {
        documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        createFile()
    }
    
    func saveSimilarPhotos(_ cache: CachedSimilarPhotos) {
        let fileURL = documentsURL.appendingPathComponent(fileName)
        do {
            let data = try JSONEncoder().encode(cache)
            try data.write(to: fileURL)
            print("\(cache.items.count) photos saved to \(fileURL.path)")
        } catch {
            print("Error in saveSimilarPhotos \(error.localizedDescription)")
        }
    }
    
    func appendSimilarPhotos(_ newItems: [CachedPhotoItem]) {
        var current = loadSimilarPhotos() ?? CachedSimilarPhotos(models: [])
        current.items.append(newItems)
        saveSimilarPhotos(current)
    }
    
    func loadSimilarPhotos() -> CachedSimilarPhotos? {
        let fileURL = documentsURL.appendingPathComponent(fileName)
        do {
            let data = try Data(contentsOf: fileURL)
            let cachedModels = try JSONDecoder().decode(CachedSimilarPhotos.self, from: data)
            return cachedModels
        } catch {
            print("Error loading preferences: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func createFile() {
        let fileURL = documentsURL.appendingPathComponent(fileName)
        if !fileManager.fileExists(atPath: fileURL.path) {
            fileManager.createFile(atPath: fileURL.path, contents: nil, attributes: nil)
        }
        print("File created at \(fileURL.path)")
    }
}
