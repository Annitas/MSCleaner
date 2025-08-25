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
    
    func process(service: VideoService, assets: PHFetchResult<PHAsset>, cache: [PhotoItem] = []) {
        switch self {
        case .screenRecordings: service.getScreenrecordings(assets: assets)
        case .videoDuplicates:  service.getVideos(assets: assets)
        }
    }
}

final class VideoService {
    @Published var isLoading = false
    @Published var grouppedDuplicatedVideos: [[VideoItem]] = []
    @Published var assetSizes: Int64 = 0
    private let cacheService = PhotosCacheService()
    private let grouppedService = MediaFetchingService()
    private let albumType: VideoAlbumType
    private let processingQueue = OperationQueue()
    
    init(albumType: VideoAlbumType) {
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
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let collection = PHAssetCollection.fetchAssetCollections(
            with: .smartAlbum,
            subtype: albumType.albumSubtype,
            options: nil
        ).firstObject
        guard let collection else { return }
        let assets = PHAsset.fetchAssets(in: collection, options: fetchOptions)
        albumType.process(service: self, assets: assets)
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
    
    func getVideos(assets: PHFetchResult<PHAsset>) {
        Task {
            processDuplicatedVideos(for: await grouppedService.getGroupedVideos(assets: assets))
            assetSizes = grouppedDuplicatedVideos.flatMap { $0 }.map { $0.data }.reduce(0) { $0 + $1 }
        }
    }
    
    func getScreenrecordings(assets: PHFetchResult<PHAsset>) {
        Task {
            grouppedDuplicatedVideos = await grouppedService.getScreenRecordings(assets: assets)
            assetSizes = grouppedDuplicatedVideos.flatMap { $0 }.map { $0.data }.reduce(0) { $0 + $1 }
        }
    }
    
    private func processDuplicatedVideos(for videos: [TimeInterval : [VideoItem]]) {
        for (_, videoItems) in videos {
            guard videoItems.count > 1 else { continue }
            grouppedDuplicatedVideos += VideoDuplicateDetector().findDuplicates(in: videoItems)
        }
    }
}
