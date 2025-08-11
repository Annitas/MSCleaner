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

final class PhotosService {
    @Published var groupedDuplicates: [[ScreenshotItem]] = []
    @Published var assetSizes: Int64 = 0
    
    private let assetSizesLock = NSLock()
    private let albumType: MediaAlbumType
    private static let sharedFeatureCache = NSCache<NSString, VNFeaturePrintObservation>()
    private let processingQueue = OperationQueue()
    private let calendar = Calendar.current
    private let imageManager = PHCachingImageManager()
    
    init(albumType: MediaAlbumType) {
        self.albumType = albumType
        processingQueue.maxConcurrentOperationCount = 2
        fetchScreenshots() // TODO: Rename to main photos
    }
    
    func fetchScreenshots() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            guard status == .authorized || status == .limited else { return }
            self.loadAssets()
        }
    }
    
    private func loadAssets() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let collection: PHAssetCollection?
        switch albumType {
        case .screenshots:
            collection = PHAssetCollection.fetchAssetCollections(
                with: .smartAlbum,
                subtype: .smartAlbumScreenshots,
                options: nil
            ).firstObject
            
        case .similarPhotos:
            fetchOptions.predicate = NSPredicate(
                format: "mediaSubtype != %d",
                PHAssetMediaSubtype.photoScreenshot.rawValue
            )
            collection = PHAssetCollection.fetchAssetCollections(
                with: .smartAlbum,
                subtype: .smartAlbumUserLibrary,
                options: nil
            ).firstObject
            
        case .screenRecordings:
            collection = PHAssetCollection.fetchAssetCollections(
                with: .smartAlbum,
                subtype: .smartAlbumVideos, // TODO: find screen recordings
                options: nil
            ).firstObject
            
        case .videoDuplicates:
            collection = PHAssetCollection.fetchAssetCollections(
                with: .smartAlbum,
                subtype: .smartAlbumVideos,
                options: nil
            ).firstObject
        }
        
        guard let collection else { return }
        let assets = PHAsset.fetchAssets(in: collection, options: fetchOptions)
        let requestOptions = PHImageRequestOptions()
        requestOptions.deliveryMode = .highQualityFormat
        requestOptions.isSynchronous = false
        var groupedByDate: [Date: [ScreenshotItem]] = [:]
        let requestImagesGroup = DispatchGroup()
        let requestImagesSemaphore = DispatchSemaphore(value: 4)
        assets.enumerateObjects { [weak self] asset, _, _  in
            guard let self = self, let creationDate = asset.creationDate else { return }
            let dateKey = self.calendar.startOfDay(for: creationDate)
            requestImagesGroup.enter()
            requestImagesSemaphore.wait()
            self.imageManager.requestImage(for: asset, targetSize: CGSize(width: 300, height: 300),
                                           contentMode: .aspectFill,
                                           options: requestOptions) { image, _ in
                defer {
                    requestImagesSemaphore.signal()
                    requestImagesGroup.leave()
                }
                guard let image else { return }
                let item = ScreenshotItem(image: image, creationDate: creationDate, asset: asset)
                groupedByDate[dateKey, default: []].append(item)
            }
        }
        
        requestImagesGroup.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            self.processDuplicatesAsync(from: groupedByDate)
            print("COMPLETED")
        }
    }
    
    func processDuplicatesAsync(from grouped: [Date: [ScreenshotItem]]) {
        for (date, items) in grouped {
            let operation = BlockOperation { [weak self] in
                self?.processDuplicates(for: date, items: items)
            }
            processingQueue.addOperation(operation)
        }
    }
    
    private func processDuplicates(for date: Date, items: [ScreenshotItem]) {
        var visited = Set<Int>()
        for i in 0..<items.count {
            guard !visited.contains(i) else { continue }
            var group = [items[i]]
            visited.insert(i)
            
            for j in (i + 1)..<items.count {
                guard !visited.contains(j) else { continue }
                if isSimilarPhotos(firstItem: items[i], secondItem: items[j]) {
                    group.append(items[j])
                    visited.insert(j)
                }
            }
            
            if group.count > 1 {
                var groupWithBest = group
                groupWithBest[0].isBest = true
                appendAssetSizes(for: group)
                groupedDuplicates.append(groupWithBest)
            }
        }
    }
    
    private func appendAssetSizes(for group: [ScreenshotItem]) {
        let assets = group.compactMap(\.asset)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var totalSize: Int64 = 0
            
            for asset in assets {
                let resources = PHAssetResource.assetResources(for: asset)
                for resource in resources where resource.type == .photo {
                    if let size = resource.value(forKey: "fileSize") as? Int64 {
                        totalSize += size
                    }
                }
            }
            
            DispatchQueue.main.async {
                self?.assetSizesLock.lock()
                self?.assetSizes += totalSize
                self?.assetSizesLock.unlock()
            }
        }
    }
    
    private func isSimilarPhotos(firstItem: ScreenshotItem, secondItem: ScreenshotItem) -> Bool {
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
}
