//
//  PhotosService.swift
//  MSCleaner
//
//  Created by Anita Stashevskaya on 08.08.2025.
//

import Photos
import Vision
import SwiftUI

enum MediaAlbumType {
    case screenshots
    case similarPhotos
    case screenRecordings
    case videoDuplicates
}

struct AssetSize {
    var screenshotSize: Int64 = 0
    var screenRecordingsSize: Int64 = 0
    var similarPhotosSize: Int64 = 0
    var similarVideosSize: Int64 = 0
}

final class PhotosService {
    @Published var groupedDuplicatedPhotos: [[PhotoItem]] = []
    @Published var grouppedDuplicatedVideos: [[VideoItem]] = []
    @Published var assetSizes: Int64 = 0
    
    private let grouppedService = MediaFetchingService()
    private let albumType: MediaAlbumType
    private let processingQueue = OperationQueue()
    
    init(albumType: MediaAlbumType) {
        self.albumType = albumType
        processingQueue.maxConcurrentOperationCount = 2
        fetchPhotos()
    }
    
    func fetchPhotos() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            guard status == .authorized || status == .limited else { return }
            self.loadAssets()
        }
    }
    
    private func loadAssets() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let collection: PHAssetCollection?
        var albumSubtype: PHAssetCollectionSubtype
        
        switch albumType {
        case .screenshots:
            albumSubtype = .smartAlbumScreenshots
        case .similarPhotos:
            albumSubtype = .smartAlbumUserLibrary
        case .screenRecordings:
            albumSubtype = .smartAlbumVideos
        case .videoDuplicates:
            albumSubtype = .smartAlbumVideos
        }
        
        collection = PHAssetCollection.fetchAssetCollections(
            with: .smartAlbum,
            subtype: albumSubtype,
            options: nil
        ).firstObject
        
        guard let collection else { return }
        let assets = PHAsset.fetchAssets(in: collection, options: fetchOptions)
        let requestOptions = PHImageRequestOptions()
        requestOptions.deliveryMode = .highQualityFormat
        requestOptions.isSynchronous = false
        
        switch albumType {
        case .screenshots:
            getScreenshots(assets: assets)
        case .similarPhotos:
            getPhotos(assets: assets)
        case .screenRecordings:
            getScreenrecordings(assets: assets)
        case .videoDuplicates:
            getVideos(assets: assets)
        }
    }
    
    func getScreenshots(assets: PHFetchResult<PHAsset>) {
        Task {
            groupedDuplicatedPhotos = await grouppedService.getScreenshots(assets: assets).values.compactMap { $0 }
        }
    }
    
    func getPhotos(assets: PHFetchResult<PHAsset>) {
        Task {
            self.processDuplicatedPhotosAsync(from: await grouppedService.getGrouppedPhotos(assets: assets))
        }
    }
    
    func getVideos(assets: PHFetchResult<PHAsset>) {
        Task {
            processDuplicatedVideos(for: await grouppedService.getGrouppedViedos(assets: assets))
        }
    }
    
    func getScreenrecordings(assets: PHFetchResult<PHAsset>) {
        Task {
            grouppedDuplicatedVideos = await grouppedService.getScreenRecordings(assets: assets)
        }
    }
    
    private func processDuplicatedVideos(for videos: [TimeInterval : [VideoItem]]) {
        for (_, videoItems) in videos {
            guard videoItems.count > 1 else { continue }
            grouppedDuplicatedVideos += VideoDuplicateDetector().findDuplicates(in: videoItems)
        }
    }
    
    private func processDuplicatedPhotosAsync(from grouped: [Date: [PhotoItem]]) {
        let operationGroup = DispatchGroup()
        
        for (_, items) in grouped {
            guard items.count > 1 else { continue }
            let operation = BlockOperation { [weak self] in
                let duplicates = PhotoDuplicateDetector().findDuplicates(in: items)
                self?.groupedDuplicatedPhotos += duplicates
            }
            operationGroup.enter()
            operation.completionBlock = {
                operationGroup.leave()
            }
            processingQueue.addOperation(operation)
        }
        
        operationGroup.notify(queue: .main) { [weak self] in
            self?.sortGroupedDuplicates()
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
