//
//  ScreenshotsViewModel.swift
//  MSCleaner
//
//  Created by Anita Stashevskaya on 06.08.2025.
//

import SwiftUI
import Photos
import Vision

final class ScreenshotsViewModel: ObservableObject {
    @Published var groupedDuplicates: [Date: [ScreenshotDuplicateGroup]] = [:]
    @Published var sortedDates: [Date] = []
    
    private let calendar = Calendar.current
    private let imageManager = PHCachingImageManager()
    private static let sharedFeatureCache = NSCache<NSString, VNFeaturePrintObservation>()
    
    init() {
        fetchScreenshots()
    }
    
    func fetchScreenshots() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            DispatchQueue.main.async {
                guard status == .authorized || status == .limited else { return }
                self.loadAssets()
            }
        }
    }
    
    private func loadAssets() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        let screenshotsAlbum = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumScreenshots, options: nil)
        
        guard let collection = screenshotsAlbum.firstObject else { return }
        let assets = PHAsset.fetchAssets(in: collection, options: fetchOptions)
        
        let requestOptions = PHImageRequestOptions()
        requestOptions.deliveryMode = .highQualityFormat
        requestOptions.isSynchronous = false
        
        DispatchQueue.global(qos: .userInitiated).async {
            var groupedByDate: [Date: [ScreenshotItem]] = [:]
            let group = DispatchGroup()
            
            assets.enumerateObjects { asset, _, _ in
                guard let creationDate = asset.creationDate else { return }
                let dateKey = self.calendar.startOfDay(for: creationDate)
                
                group.enter()
                self.imageManager.requestImage(for: asset, targetSize: CGSize(width: 200, height: 200), contentMode: .aspectFill, options: requestOptions) { image, _ in
                    defer { group.leave() }
                    guard let image = image else { return }
                    let item = ScreenshotItem(image: image, creationDate: creationDate, asset: asset)
                    groupedByDate[dateKey, default: []].append(item)
                }
            }
            
            group.notify(queue: .main) {
                self.processDuplicatesAsync(from: groupedByDate)
            }
        }
    }
    
    func processDuplicatesAsync(from grouped: [Date: [ScreenshotItem]]) {
        Task.detached(priority: .userInitiated) {
            for (date, items) in grouped {
                await self.processDuplicates(for: date, items: items)
            }
        }
    }
    
    @MainActor
    private func processDuplicates(for date: Date, items: [ScreenshotItem]) async {
        var visited = Set<Int>()
        var dateGroups: [ScreenshotDuplicateGroup] = []
        
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
                dateGroups.append(ScreenshotDuplicateGroup(duplicates: group))
            }
        }
        
        if !dateGroups.isEmpty {
            groupedDuplicates[date] = dateGroups
            if !sortedDates.contains(date) {
                sortedDates.append(date)
                sortedDates.sort(by: >)
            }
        }
    }
    
    private func isSimilarPhotos(firstItem: ScreenshotItem, secondItem: ScreenshotItem) -> Bool {
        var distance: Float = 0
        if let fp1 = featurePrintForImage(image: firstItem.image, cacheKey: firstItem.asset.localIdentifier),
           let fp2 = featurePrintForImage(image: secondItem.image, cacheKey: secondItem.asset.localIdentifier) {
            try? fp1.computeDistance(&distance, to: fp2)
        }
        return distance <= 0.3
    }
    
    private func featurePrintForImage(image: UIImage, cacheKey: String) -> VNFeaturePrintObservation? {
        if let cached = Self.sharedFeatureCache.object(forKey: cacheKey as NSString) {
            return cached
        }
        
        guard let cgImage = image.cgImage else { return nil }
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNGenerateImageFeaturePrintRequest()
        try? handler.perform([request])
        
        if let result = request.results?.first as? VNFeaturePrintObservation {
            Self.sharedFeatureCache.setObject(result, forKey: cacheKey as NSString)
            return result
        }
        
        return nil
    }
    
    @MainActor
    func toggleSelection(for item: ScreenshotItem) {
        for (date, groups) in groupedDuplicates {
            for groupIndex in groups.indices {
                for itemIndex in groupedDuplicates[date]![groupIndex].duplicates.indices {
                    if groupedDuplicates[date]![groupIndex].duplicates[itemIndex].id == item.id {
                        groupedDuplicates[date]![groupIndex].duplicates[itemIndex].isSelected.toggle()
                        objectWillChange.send()
                        return
                    }
                }
            }
        }
    }
    
    @MainActor
    func deleteSelected() {
        var assetsToDelete: [PHAsset] = []
        
        for groups in groupedDuplicates.values {
            for group in groups {
                for item in group.duplicates where item.isSelected {
                    assetsToDelete.append(item.asset)
                }
            }
        }
        
        guard !assetsToDelete.isEmpty else { return }
        
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets(assetsToDelete as NSArray)
        }) { success, error in
            DispatchQueue.main.async {
                if success {
                    print("Deleted selected items")
                    self.fetchScreenshots()
                } else if let error = error {
                    print("Deletion failed: \(error)")
                }
            }
        }
    }
}
