//
//  PhotoDuplicateDetector.swift
//  MSCleaner
//
//  Created by Anita Stashevskaya on 16.08.2025.
//

import SwiftUI
import Vision
import Photos

final class PhotoDuplicateDetector {
    private static let sharedFeatureCache = NSCache<NSString, VNFeaturePrintObservation>()
    
    func findDuplicates(in items: [PhotoItem]) -> [[PhotoItem]] {
        var visited = Set<Int>()
        var groups: [[PhotoItem]] = []
        
        for i in 0..<items.count {
            guard !visited.contains(i) else { continue }
            var group = [items[i]]
            visited.insert(i)
            
            for j in (i+1)..<items.count {
                guard !visited.contains(j) else { continue }
                if isSimilarPhotos(firstItem: items[i], secondItem: items[j]) {
                    var duplicate = items[j]
                    duplicate.isSelected = true
                    group.append(duplicate)
                    visited.insert(j)
                }
            }
            
            if group.count > 1 {
                let groupWithBest = markBest(in: group)
                groups.append(setSizes(in: groupWithBest))
            }
        }
        return groups
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
    
    private func markBest(in group: [PhotoItem]) -> [PhotoItem] {
        var updated = group
        updated[0].isBest = true
        updated[0].isSelected = false
        return updated
    }
    
    private func setSizes(in group: [PhotoItem]) -> [PhotoItem] {
        let assetSize = getSizeOfAsset(group.first?.asset)
        return group.map { item in
            var copy = item
            copy.data = assetSize
            return copy
        }
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
