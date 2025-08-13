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
    @Published var groupedDuplicates: [[PhotoItem]] = []
    @Published var assetSizes: Int64 = 0
    
    private let grouppedService = MediaGrouppingService()
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
        
        Task {
            self.processDuplicatesAsync(from: await grouppedService.getGrouppedPhotos(assets: assets))
        }
    }
    
    func processDuplicatesAsync(from grouped: [Date: [PhotoItem]]) {
        let operationGroup = DispatchGroup()
        
        for (date, items) in grouped {
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
                appendAssetSizes(for: group)
                groupedDuplicates.append(groupWithBest)
            }
        }
    }
    
    private func sortGroupedDuplicates() {
        DispatchQueue.main.async { [weak self] in
            self?.groupedDuplicates.sort { group1, group2 in
                let date1 = group1.first?.creationDate ?? Date.distantPast
                let date2 = group2.first?.creationDate ?? Date.distantPast
                return date1 > date2
            }
        }
    }
    
    private func appendAssetSizes(for group: [PhotoItem]) {
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
        return distance <= 0.15
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
    
    func getSizeOfAsset(_ asset: PHAsset) -> Int64 {
        let resources = PHAssetResource.assetResources(for: asset)
        guard let resource = resources.first else { return 0 }
        if let fileSize = resource.value(forKey: "fileSize") as? Int64 {
            return fileSize
        }
        return 0
    }
}
