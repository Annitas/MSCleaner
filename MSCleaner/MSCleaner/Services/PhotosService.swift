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
    
    var albumSubtype: PHAssetCollectionSubtype {
        switch self {
        case .screenshots:      return .smartAlbumScreenshots
        case .similarPhotos:    return .smartAlbumUserLibrary
        case .screenRecordings: return .smartAlbumVideos
        case .videoDuplicates:  return .smartAlbumVideos
        }
    }
    
    func process(service: PhotosService, assets: PHFetchResult<PHAsset>) {
        switch self {
        case .screenshots:      service.getScreenshots(assets: assets)
        case .similarPhotos:    service.getPhotos(assets: assets)
        case .screenRecordings: service.getScreenrecordings(assets: assets)
        case .videoDuplicates:  service.getVideos(assets: assets)
        }
    }
}

final class PhotosService {
    @Published var isLoading = false
    @Published var groupedDuplicatedPhotos: [[PhotoItem]] = []
    @Published var grouppedDuplicatedVideos: [[VideoItem]] = []
    @Published var assetSizes: Int64 = 0
    
    private let grouppedService = MediaFetchingService()
    private let albumType: MediaAlbumType
    private let processingQueue = OperationQueue()
    
    init(albumType: MediaAlbumType) {
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
    
    func getScreenshots(assets: PHFetchResult<PHAsset>) {
        Task {
            groupedDuplicatedPhotos = await grouppedService.getScreenshots(assets: assets).values.compactMap { $0 }
            assetSizes = groupedDuplicatedPhotos.flatMap { $0 }.map { $0.data }.reduce(0) { $0 + $1 }
        }
    }
    
    func getPhotos(assets: PHFetchResult<PHAsset>) {
        Task {
            self.processDuplicatedPhotosAsync(from: await grouppedService.getGroupedPhotos(assets: assets))
        }
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
    
    private func processDuplicatedPhotosAsync(from grouped: [Date: [PhotoItem]]) {
        let operationGroup = DispatchGroup()
        isLoading = true
        let duplicatesDetector = PhotoDuplicateDetector()
        for (_, items) in grouped {
            guard items.count > 1 else { continue }
            let operation = BlockOperation { [weak self] in
                autoreleasepool {
                    guard let self else { return }
                    let duplicates = duplicatesDetector.findDuplicates(in: items)
                    self.groupedDuplicatedPhotos += duplicates
                    self.assetSizes += duplicates.flatMap { $0 }.map { $0.data }.reduce(0) { $0 + $1 }
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
            self.isLoading = false
            self.sortGroupedDuplicates()
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
