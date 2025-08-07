//
//  ScreenshotsViewModel.swift
//  MSCleaner
//
//  Created by Anita Stashevskaya on 06.08.2025.
//

import SwiftUI
import Photos
import Vision

struct ScreenshotDuplicateGroup: Identifiable {
    let id = UUID()
    let duplicates: [ScreenshotItem]
}

final class ScreenshotsViewModel: ObservableObject {
    @Published var groupedDuplicates: [Date: [ScreenshotDuplicateGroup]] = [:]
    @Published var sortedDates: [Date] = []
    
    private let calendar = Calendar.current
    private let imageManager = PHCachingImageManager()
    private let processingQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "PhotoComparisonQueue"
        queue.maxConcurrentOperationCount = 2
        return queue
    }()
    
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
        
        let screenshotsAlbum = PHAssetCollection.fetchAssetCollections(
            with: .smartAlbum,
            subtype: .smartAlbumScreenshots,
            options: nil
        )
        
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
                self.imageManager.requestImage(for: asset, targetSize: CGSize(width: 300, height: 300), contentMode: .aspectFill, options: requestOptions) { image, _ in
                    defer { group.leave() }
                    guard let image = image else { return }
                    let item = ScreenshotItem(image: image, creationDate: creationDate)
                    
                    groupedByDate[dateKey, default: []].append(item)
                }
            }
            
            group.notify(queue: .main) {
                self.processDuplicatesAsync(from: groupedByDate)
            }
        }
    }
    
    func processDuplicatesAsync(from grouped: [Date: [ScreenshotItem]]) {
        for (date, items) in grouped {
            let operation = BlockOperation {
                let result = self.findDuplicates(in: items)
                guard !result.isEmpty else { return }
                
                Task { @MainActor in
                    self.groupedDuplicates[date, default: []].append(contentsOf: result)
                    
                    if !self.sortedDates.contains(date) {
                        self.sortedDates.append(date)
                        self.sortedDates.sort(by: >)
                    }
                }
            }
            processingQueue.addOperation(operation)
        }
    }
    
    private func findDuplicates(in items: [ScreenshotItem]) -> [ScreenshotDuplicateGroup] {
        var visited = Set<Int>()
        var results: [ScreenshotDuplicateGroup] = []
        
        for i in 0..<items.count {
            guard !visited.contains(i) else { continue }
            var group = [items[i]]
            visited.insert(i)
            
            for j in (i + 1)..<items.count {
                guard !visited.contains(j) else { continue }
                if isSimilarPhotos(firstImage: items[i].image, secondImage: items[j].image) {
                    group.append(items[j])
                    visited.insert(j)
                }
            }
            
            if group.count > 1 {
                results.append(ScreenshotDuplicateGroup(duplicates: group))
            }
        }
        return results
    }
    
    private func isSimilarPhotos(firstImage: UIImage, secondImage: UIImage) -> Bool {
        var distance: Float = 0
        if let fp1 = featurePrintForImage(image: firstImage),
           let fp2 = featurePrintForImage(image: secondImage) {
            try? fp1.computeDistance(&distance, to: fp2)
        }
        return distance <= 0.3
    }
    
    private func featurePrintForImage(image: UIImage) -> VNFeaturePrintObservation? {
        guard let cgImage = image.cgImage else { return nil }
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNGenerateImageFeaturePrintRequest()
        try? handler.perform([request])
        return request.results?.first as? VNFeaturePrintObservation
    }
}

