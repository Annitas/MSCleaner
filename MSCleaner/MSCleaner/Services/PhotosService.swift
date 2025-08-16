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
    private let assetSizesLock = NSLock()
    private let albumType: MediaAlbumType
    private static let sharedFeatureCache = NSCache<NSString, VNFeaturePrintObservation>()
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
        var visited = Set<UUID>()
        for (_, videoItems) in videos {
            guard videoItems.count > 1 else { continue }
            
            for i in 0..<videoItems.count {
                let id1 = videoItems[i].id
                guard !visited.contains(id1) else { continue }
                var duplicates = [videoItems[i]]
                visited.insert(id1)
                for j in (i+1)..<videoItems.count {
                    let id2 = videoItems[j].id
                    guard !visited.contains(id2) else { continue }
                    let isDuplicate = (0..<3).allSatisfy { idx in
                        videoItems[i].images[idx].pngData() == videoItems[j].images[idx].pngData()
                    }
                    if isDuplicate {
                        duplicates.append(videoItems[j])
                        visited.insert(id2)
                    }
                }
                if duplicates.count > 1 {
                    grouppedDuplicatedVideos.append(duplicates)
                }
            }
        }
    }
    
    private func processDuplicatedPhotosAsync(from grouped: [Date: [PhotoItem]]) {
        let operationGroup = DispatchGroup()
        
        for (date, items) in grouped {
            guard items.count > 1 else { continue }
            let operation = BlockOperation { [weak self] in
                self?.processDuplicates(for: date, items: items)
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
    
    private func processDuplicates(for date: Date, items: [PhotoItem]) {
        var visited = Set<Int>()
        for i in 0 ..< items.count {
            guard !visited.contains(i) else { continue }
            var group = [items[i]]
            visited.insert(i)
            
            for j in (i + 1) ..< items.count {
                guard !visited.contains(j) else { continue }
                if isSimilarPhotos(firstItem: items[i], secondItem: items[j]) {
                    var itemToAppend = items[j]
                    itemToAppend.isSelected = true
                    group.append(itemToAppend)
                    visited.insert(j)
                }
            }
            
            if group.count > 1 {
                var groupWithBest = group
                groupWithBest[0].isBest = true
                groupWithBest[0].isSelected = false
                
                if let asset = group.first?.asset {
                    let size = getSizeOfAsset(asset)
                    for index in 0..<groupWithBest.count {
                        groupWithBest[index].data = size
                    }
                    assetSizes += size * Int64(groupWithBest.count)
                }
                
                groupedDuplicatedPhotos.append(groupWithBest)
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
    
    private func isSimilarPhotos(firstItem: PhotoItem, secondItem: PhotoItem) -> Bool {
        var distance: Float = 0
        do {
            if let fp1 = featurePrintForImage(image: firstItem.image, cacheKey: firstItem.asset.localIdentifier),
               let fp2 = featurePrintForImage(image: secondItem.image, cacheKey: secondItem.asset.localIdentifier) {
                try fp1.computeDistance(&distance, to: fp2)
            }
        } catch {
            print("!!! Error isSimilarPhotos")
            return false
        }
        return distance <= 0.2
    }
    
    private func featurePrintForImage(image: UIImage, cacheKey: String) -> VNFeaturePrintObservation? {
        if let cached = Self.sharedFeatureCache.object(forKey: cacheKey as NSString) {
            return cached
        }
        
        guard let cgImage = image.cgImage else { return nil }
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNGenerateImageFeaturePrintRequest()
        
        do {
            try handler.perform([request])
            if let result = request.results?.first as? VNFeaturePrintObservation {
                Self.sharedFeatureCache.setObject(result, forKey: cacheKey as NSString)
                return result
            }
        } catch {
            print("!!! Error featurePrintForImage: \(error)")
        }
        
        return nil
    }
    
    private func getSizeOfAsset(_ asset: PHAsset?) -> Int64 {
        guard let asset else { return 0 }
        let resources = PHAssetResource.assetResources(for: asset)
        guard let resource = resources.first else { return 0 }
        if let fileSize = resource.value(forKey: "fileSize") as? Int64 {
            return fileSize
        }
        return 0
    }
}
