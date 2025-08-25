//
//  NewPhotoService.swift
//  MSCleaner
//
//  Created by Anita Stashevskaya on 23.08.2025.
//

import SwiftUI
import Photos

enum VideoAlbumType {
    case screenRecordings
    case videoDuplicates
    
    var albumSubtype: PHAssetCollectionSubtype {
        switch self {
        case .screenRecordings: return .smartAlbumVideos
        case .videoDuplicates:  return .smartAlbumVideos
        }
    }
    
    var cacheFileName: String {
        switch self {
        case .screenRecordings: return "cleanerScreenRecordings.json"
        case .videoDuplicates:  return "cleanerVideoDuplicates.json"
        }
    }
    
    func process(service: VideoService, assets: PHFetchResult<PHAsset>, cache: [[VideoItem]] = []) {
        switch self {
        case .screenRecordings: service.getScreenrecordings(assets: assets, cache: cache)
        case .videoDuplicates:  service.getVideos(assets: assets, cache: cache)
        }
    }
}

final class VideoService {
    @Published var isLoading = false
    @Published var grouppedDuplicatedVideos: [[VideoItem]] = []
    @Published var assetSizes: Int64 = 0
    private let cacheService = VideoCacheService()
    private let grouppedService = MediaFetchingService()
    private let albumType: VideoAlbumType
    
    init(albumType: VideoAlbumType) {
        self.albumType = albumType
        fetchVideos()
    }
    
    func fetchVideos() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
            guard status == .authorized || status == .limited else { return }
            self?.loadAssets()
        }
    }
    
    private func loadAssets() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let collection = PHAssetCollection.fetchAssetCollections(
            with: .smartAlbum,
            subtype: albumType.albumSubtype,
            options: nil
        ).firstObject
        guard let collection else { return }
        let newestAssetCreationDate = fetchLatestVideoAsset()?.creationDate ?? Date.distantPast
        if let cache = cacheService.load(albumType, as: CachedVideos.self) {
            if cache.latestVideoDate == newestAssetCreationDate {
                grouppedDuplicatedVideos = cache.items.compactMap { $0 }
                assetSizes = grouppedDuplicatedVideos.flatMap { $0 }.map { $0.data }.reduce(0, +)
                loading(is: false)
            } else {
                fetchOptions.predicate = NSPredicate(format: "creationDate > %@", cache.latestVideoDate as NSDate)
                let cacheVideos = cache.items.flatMap { $0 }
                let assets = PHAsset.fetchAssets(in: collection, options: fetchOptions)
                albumType.process(service: self, assets: assets, cache: [cacheVideos])
            }
        } else {
            let assets = PHAsset.fetchAssets(in: collection, options: fetchOptions)
            albumType.process(service: self, assets: assets)
        }
    }
    
    func fetchLatestVideoAsset() -> PHAsset? {
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
        
        if albumType == .screenRecordings {
            return (0..<assets.count)
                .map { assets.object(at: $0) }
                .first { asset in
                    let resources = PHAssetResource.assetResources(for: asset)
                    if let filename = resources.first?.originalFilename.lowercased() {
                        return filename.contains("rpreplay_final") || filename.contains("screenrecording")
                    }
                    return false
                }
        }
        return assets.firstObject
    }
    
    func getVideos(assets: PHFetchResult<PHAsset>, cache: [[VideoItem]] = []) {
        Task {
            processDuplicatedVideos(for: await grouppedService.getGroupedVideos(assets: assets), cache: cache)
            assetSizes = grouppedDuplicatedVideos.flatMap { $0 }.map { $0.data }.reduce(0) { $0 + $1 }
        }
    }
    
    func getScreenrecordings(assets: PHFetchResult<PHAsset>, cache: [[VideoItem]] = []) {
        Task {
            let newModels = await grouppedService.getScreenRecordings(assets: assets)
            let latestVideoDate = newModels
                .flatMap { $0 }
                .map { $0.creationDate }
                .max() ?? Date.distantPast
            grouppedDuplicatedVideos = newModels + cache
            cacheService.save(CachedVideos(items: grouppedDuplicatedVideos, latestVideoDate: latestVideoDate), for: albumType)
            assetSizes = grouppedDuplicatedVideos.flatMap { $0 }.map { $0.data }.reduce(0) { $0 + $1 }
        }
    }
    
    private func processDuplicatedVideos(for videos: [[VideoItem]], cache: [[VideoItem]] = []) {
        let latestVideoDate = videos
            .flatMap({ $0 })
            .map { $0.creationDate }
            .max() ?? Date.distantPast
        for videoItems in videos {
            guard videoItems.count > 1 else { continue }
            grouppedDuplicatedVideos += VideoDuplicateDetector().findDuplicates(in: videoItems)
        }
        grouppedDuplicatedVideos += cache
        cacheService.save(CachedVideos(items: grouppedDuplicatedVideos, latestVideoDate: latestVideoDate), for: albumType)
    }
    
    private func loading(is state: Bool) {
        Task {
            await MainActor.run {
                isLoading = state
            }
        }
    }
}
