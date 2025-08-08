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
    @Published var selectedItemCount = 0
    @Published var deletedDataAmount: Int64 = 0
    
    private let calendar = Calendar.current
    private let imageManager = PHCachingImageManager()
    private static let sharedFeatureCache = NSCache<NSString, VNFeaturePrintObservation>()
    
    private let processingQueue = OperationQueue()
    private let sortedDatesQueue = DispatchQueue(label: "sortedDatesQueue", attributes: .concurrent)
    
    init() {
        processingQueue.maxConcurrentOperationCount = 4
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
            let lock = NSLock()
            
            assets.enumerateObjects { [weak self] asset, _, _ in
                guard let self = self, let creationDate = asset.creationDate else { return }
                let dateKey = self.calendar.startOfDay(for: creationDate)
                
                group.enter()
                self.imageManager.requestImage(for: asset, targetSize: CGSize(width: 300, height: 300), contentMode: .aspectFill, options: requestOptions) { image, _ in
                    guard let image else {
                        group.leave()
                        return
                    }
                    
                    let item = ScreenshotItem(image: image, creationDate: creationDate, asset: asset)
                    lock.lock()
                    groupedByDate[dateKey, default: []].append(item)
                    lock.unlock()
                    group.leave()
                }
            }
            
            group.notify(queue: .main) { [weak self] in
                guard let self = self else { return }
                self.processDuplicatesAsync(from: groupedByDate)
            }
        }
    }
    
    func processDuplicatesAsync(from grouped: [Date: [ScreenshotItem]]) {
        for (date, items) in grouped {
            processingQueue.addOperation { [weak self] in
                self?.processDuplicates(for: date, items: items)
            }
        }
    }
    
    private func processDuplicates(for date: Date, items: [ScreenshotItem]) {
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
            Task { @MainActor in
                self.updateGroupedDuplicates(date: date, groups: dateGroups)
            }
        }
    }
    
    @MainActor
    private func updateGroupedDuplicates(date: Date, groups: [ScreenshotDuplicateGroup]) {
        groupedDuplicates[date] = groups
        sortedDatesQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if !self.sortedDates.contains(date) {
                    self.sortedDates.append(date)
                    self.sortedDates.sort(by: >)
                }
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
        return distance <= 0.3
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
    
    @MainActor
    func toggleSelection(for item: ScreenshotItem) {
        guard let (date, groupIndex, itemIndex) = findItemIndices(for: item) else { return }
        guard let groups = groupedDuplicates[date], groupIndex < groups.count, itemIndex < groups[groupIndex].duplicates.count else {
            print("!!! Error toggleSelection")
            return
        }
        
        groupedDuplicates[date]![groupIndex].duplicates[itemIndex].isSelected.toggle()
        
        let isSelected = groupedDuplicates[date]![groupIndex].duplicates[itemIndex].isSelected
        let photoDataSize = getAssetFileSize(for: item.asset)
        
        if isSelected {
            deletedDataAmount += photoDataSize
            selectedItemCount += 1
        } else {
            deletedDataAmount -= photoDataSize
            selectedItemCount -= 1
        }
        
        objectWillChange.send()
    }
    
    private func findItemIndices(for item: ScreenshotItem) -> (Date, Int, Int)? {
        for (date, groups) in groupedDuplicates {
            for (groupIndex, group) in groups.enumerated() {
                for (itemIndex, duplicate) in group.duplicates.enumerated() {
                    if duplicate.id == item.id {
                        return (date, groupIndex, itemIndex)
                    }
                }
            }
        }
        return nil
    }
    
    private func getAssetFileSize(for asset: PHAsset) -> Int64 {
        let resources = PHAssetResource.assetResources(for: asset)
        if resources.first(where: { $0.type == .photo }) != nil {
            let requestOptions = PHImageRequestOptions()
            requestOptions.isSynchronous = true
            requestOptions.deliveryMode = .fastFormat
            
            var fileSize: Int64 = 0
            let semaphore = DispatchSemaphore(value: 0)
            
            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: requestOptions) { data, _, _, _ in
                fileSize = Int64(data?.count ?? 0)
                semaphore.signal()
            }
            
            _ = semaphore.wait(timeout: .now() + 2.0)
            return fileSize
        }
        
        return 0
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
        }) { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    self?.resetSelection()
                    self?.fetchScreenshots()
                } else if let error = error {
                    print("!!! Error deleteSelected \(error)")
                }
            }
        }
    }
    
    @MainActor
    private func resetSelection() {
        selectedItemCount = 0
        deletedDataAmount = 0
    }
}
