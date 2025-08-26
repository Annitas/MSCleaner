//
//  PhotosService.swift
//  MSCleaner
//
//  Created by Anita Stashevskaya on 08.08.2025.
//

import Photos
import Vision
import SwiftUI

enum PhotoAlbumType {
    case screenshots
    case similarPhotos
    
    var albumSubtype: PHAssetCollectionSubtype {
        switch self {
        case .screenshots:      return .smartAlbumScreenshots
        case .similarPhotos:    return .smartAlbumUserLibrary
        }
    }
    
    var cacheFileName: String {
        switch self {
        case .screenshots:      return "cleanerScreenshots.json"
        case .similarPhotos:    return "cleanerSimilarPhotos.json"
        }
    }
    
    func process(service: PhotosService, assets: PHFetchResult<PHAsset>, cache: [[PhotoItem]] = []) {
        switch self {
        case .screenshots:      service.getScreenshots(assets: assets, cache: cache)
        case .similarPhotos:    service.getPhotos(assets: assets, cache: cache)
        }
    }
}

final class PhotosService {
    @Published var isLoading = false
    @Published var groupedDuplicatedPhotos: [[PhotoItem]] = []
    @Published var assetSizes: Int64 = 0
    private let cacheService = PhotosCacheService()
    private let grouppedService = MediaFetchingService()
    private let albumType: PhotoAlbumType
    private let processingQueue = OperationQueue()
    
    init(albumType: PhotoAlbumType) {
        self.albumType = albumType
        processingQueue.maxConcurrentOperationCount = 3
        fetchPhotos()
    }
    
    func fetchPhotos() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
            guard status == .authorized || status == .limited else { return }
            self?.loadAssets()
        }
    }
    
    private func loadAssets() {
        loading(is: true)
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let collection = PHAssetCollection.fetchAssetCollections(
            with: .smartAlbum,
            subtype: albumType.albumSubtype,
            options: nil
        ).firstObject
        guard let collection else { return }
        let newestAssetCreationDate = fetchLatestPhotoAsset()?.creationDate ?? Date.distantPast
        if let cache = cacheService.load(albumType, as: CachedPhotos.self) {
            if cache.latestPhotoDate == newestAssetCreationDate {
                groupedDuplicatedPhotos = cache.items
                loading(is: false)
            } else {
                fetchOptions.predicate = NSPredicate(format: "creationDate > %@", cache.latestPhotoDate as NSDate)
                let cachePhotos = cache.items
                let assets = PHAsset.fetchAssets(in: collection, options: fetchOptions)
                albumType.process(service: self, assets: assets, cache: cachePhotos)
            }
            assetSizes = groupedDuplicatedPhotos.flatMap { $0 }.map { $0.data }.reduce(0, +)
        } else {
            let assets = PHAsset.fetchAssets(in: collection, options: fetchOptions)
            albumType.process(service: self, assets: assets)
        }
    }
    
    func getScreenshots(assets: PHFetchResult<PHAsset>, cache: [[PhotoItem]] = []) {
        Task {
            let newModels = await grouppedService.getScreenshots(assets: assets)
            let latestPhotoDate = newModels
                .map { $0.creationDate }
                .max() ?? Date.distantPast
            groupedDuplicatedPhotos = [newModels + cache.flatMap { $0 }]
            cacheService.save(CachedPhotos(items: groupedDuplicatedPhotos, latestPhotoDate: latestPhotoDate), for: albumType)
            assetSizes = groupedDuplicatedPhotos.flatMap { $0 }.map { $0.data }.reduce(0, +)
            loading(is: false)
        }
    }
    
    func fetchLatestPhotoAsset() -> PHAsset? {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = 1
        let collection = PHAssetCollection.fetchAssetCollections(
            with: .smartAlbum,
            subtype: albumType.albumSubtype,
            options: nil
        ).firstObject
        guard let collection else { return nil }
        let assets = PHAsset.fetchAssets(in: collection, options: fetchOptions)
        return assets.firstObject
    }
    
    func getPhotos(assets: PHFetchResult<PHAsset>, cache: [[PhotoItem]] = []) {
        Task {
            let newModels = await grouppedService.getGroupedPhotos(assets: assets)
            self.processDuplicatedPhotosAsync(from: newModels, cache: cache)
        }
    }
    
    private func processDuplicatedPhotosAsync(from freshPhotos: [[PhotoItem]], cache: [[PhotoItem]]) {
        let latestPhotoDate = freshPhotos
            .flatMap({ $0 })
            .map { $0.creationDate }
            .max() ?? Date.distantPast
        let operationGroup = DispatchGroup()
        let duplicatesDetector = PhotoDuplicateDetector()
        for items in freshPhotos {
            guard items.count > 1 else { continue }
            let operation = BlockOperation { [weak self] in
                autoreleasepool {
                    guard let self else { return }
                    let duplicates = duplicatesDetector.findDuplicates(in: items)
                    self.groupedDuplicatedPhotos += duplicates
                }
            }
            operationGroup.enter()
            operation.completionBlock = {
                operationGroup.leave()
            }
            processingQueue.addOperation(operation)
        }
        
        operationGroup.notify(queue: .main) { [weak self] in
            guard let self else { return }
            self.groupedDuplicatedPhotos += cache
            cacheService.save(CachedPhotos(items: self.groupedDuplicatedPhotos, latestPhotoDate: latestPhotoDate), for: albumType)
            self.loading(is: false)
            self.sortGroupedDuplicates()
        }
    }
    
    private func loading(is state: Bool) {
        Task {
            await MainActor.run {
                isLoading = state
            }
        }
    }
    
    private func sortGroupedDuplicates() {
        DispatchQueue.main.async { [weak self] in
            self?.groupedDuplicatedPhotos.sort { group1, group2 in
                let date1 = group1.first?.creationDate ?? Date.distantPast
                let date2 = group2.first?.creationDate ?? Date.distantPast
                return date1 > date2
            }
        }
    }
}
