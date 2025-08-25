//
//  VideoDuplicateDetector.swift
//  MSCleaner
//
//  Created by Anita Stashevskaya on 16.08.2025.
//

import Foundation
import Photos

final class VideoDuplicateDetector {
    func findDuplicates(in items: [VideoItem]) -> [[VideoItem]] {
        var visited = Set<UUID>()
        var groups: [[VideoItem]] = []
        
        for i in 0..<items.count {
            guard !visited.contains(items[i].id) else { continue }
            var group = [items[i]]
            visited.insert(items[i].id)
            
            for j in (i+1)..<items.count {
                guard !visited.contains(items[j].id) else { continue }
                
                let isDuplicate = (0..<3).allSatisfy { idx in
                    items[i].images[idx].pngData() == items[j].images[idx].pngData()
                }
                
                if isDuplicate {
                    group.append(items[j])
                    visited.insert(items[j].id)
                }
            }
            
            if group.count > 1 {
                let groupWithBest = markBest(in: group)
//                groups.append(setSizes(in: groupWithBest))
                groups.append(groupWithBest)
            }
        }
        return groups
    }
    
    private func markBest(in group: [VideoItem]) -> [VideoItem] {
        var updated = group
        updated[0].isBest = true
        updated[0].isSelected = false
        return updated
    }
    
//    private func setSizes(in group: [VideoItem]) -> [VideoItem] {
//        let assetSize = getSizeOfAsset(group.first?.asset)
//        return group.map { item in
//            var copy = item
//            copy.data = assetSize
//            return copy
//        }
//    }
    
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
