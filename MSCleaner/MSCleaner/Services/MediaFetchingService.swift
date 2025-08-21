//
//  GrouppingService.swift
//  MSCleaner
//
//  Created by Anita Stashevskaya on 13.08.2025.
//

import Photos
import SwiftUI

final class MediaFetchingService {
    private let calendar = Calendar.current
    private let imageManager = PHCachingImageManager()
    
    func getScreenshots(assets: PHFetchResult<PHAsset>) async -> [Date: [PhotoItem]] {
        let requestOptions = PHImageRequestOptions()
        requestOptions.deliveryMode = .highQualityFormat
        requestOptions.isSynchronous = false
        var groupedByDate: [Date: [PhotoItem]] = [:]
        let dateKey = Date()
        for i in 0 ..< assets.count {
            let asset = assets.object(at: i)
            guard let creationDate = asset.creationDate else { continue }
            if let image = await imageManager.requestUIImage(for: asset,
                                                             targetSize: CGSize(width: 300, height: 300),
                                                             options: requestOptions) {
                let item = PhotoItem(image: image, creationDate: creationDate, asset: asset, data: self.getSizeOfAsset(asset))
                groupedByDate[dateKey, default: []].append(item)
            }
        }
        print("SCREENSHOTS COMPLETED")
        return groupedByDate
    }
    
    func getScreenRecordings(assets: PHFetchResult<PHAsset>) async -> [[VideoItem]] {
        var groupedByDuration: [VideoItem] = []
        var videoAssets: [PHAsset] = []
        
        assets.enumerateObjects { asset, _, _ in
            guard asset.mediaType == .video else { return }
            let resources = PHAssetResource.assetResources(for: asset)
            if let filename = resources.first?.originalFilename.lowercased(),
               filename.contains("rpreplay_final") || filename.contains("screenrecording") {
                videoAssets.append(asset)
            }
        }
        
        await withTaskGroup(of: VideoItem?.self) { group in
            for asset in videoAssets {
                group.addTask { [self] in
                    let duration = round(asset.duration)
                    let fileSize = await getVideoFileSize(for: asset)
                    let frames = await requestPreviewFrames(for: asset,
                                                            targetSize: CGSize(width: 300, height: 300))
                    guard frames.count == 3 else { return nil }
                    return VideoItem(images: frames,
                                     asset: asset,
                                     data: fileSize,
                                     duration: duration)
                }
            }
            
            for await result in group {
                if let videoItem = result {
                    groupedByDuration.append(videoItem)
                }
            }
        }
        print("SCREENRECORDINGS COMPLETED")
        return [groupedByDuration]
    }
    
    func getGroupedPhotos(assets: PHFetchResult<PHAsset>) async -> [Date: [PhotoItem]] {
        var groupedByDate: [Date: [PhotoItem]] = [:]
        
        let requestOptions = PHImageRequestOptions()
        requestOptions.deliveryMode = .highQualityFormat
        requestOptions.isSynchronous = false
        
        for i in 0 ..< assets.count {
            let asset = assets.object(at: i)
            guard let creationDate = asset.creationDate else { continue }
            let dateKey = calendar.startOfDay(for: creationDate)
            
            if let image = await imageManager.requestUIImage(for: asset,
                                                             targetSize: CGSize(width: 300, height: 300),
                                                             options: requestOptions) {
                let item = PhotoItem(image: image, creationDate: creationDate, asset: asset)
                groupedByDate[dateKey, default: []].append(item)
            }
        }
        print("PHOTOS COMPLETED")
        return groupedByDate
    }
    
    func getGroupedVideos(assets: PHFetchResult<PHAsset>) async -> [TimeInterval: [VideoItem]] {
        var groupedByDuration: [TimeInterval: [VideoItem]] = [:]
        var videoAssets: [PHAsset] = []
        assets.enumerateObjects { asset, _, _ in
            if asset.mediaType == .video {
                videoAssets.append(asset)
            }
        }
        await withTaskGroup(of: (TimeInterval, VideoItem)?.self) { group in
            for asset in videoAssets {
                group.addTask { [self] in
                    let duration = round(asset.duration)
                    let fileSize = await getVideoFileSize(for: asset)
                    let frames = await requestPreviewFrames(for: asset,
                                                            targetSize: CGSize(width: 300, height: 300))
                    guard frames.count == 3 else { return nil }
                    let videoItem = VideoItem(images: frames,
                                              asset: asset,
                                              data: fileSize,
                                              duration: duration)
                    return (duration, videoItem)
                }
            }
            
            for await result in group {
                if let (duration, videoItem) = result {
                    groupedByDuration[duration, default: []].append(videoItem)
                }
            }
        }
        
        print("VIDEOS COMPLETED")
        return groupedByDuration
    }
    
    private func requestPreviewFrames(for asset: PHAsset, targetSize: CGSize) async -> [UIImage] {
        await withCheckedContinuation { continuation in
            let options = PHVideoRequestOptions()
            options.version = .current
            options.deliveryMode = .highQualityFormat
            
            PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
                guard let avAsset = avAsset else {
                    continuation.resume(returning: [])
                    return
                }
                
                let generator = AVAssetImageGenerator(asset: avAsset)
                generator.appliesPreferredTrackTransform = true
                generator.maximumSize = targetSize
                
                let durationSeconds = CMTimeGetSeconds(avAsset.duration)
                let times = [
                    CMTime(seconds: 0, preferredTimescale: 600),
                    CMTime(seconds: durationSeconds / 2, preferredTimescale: 600),
                    CMTime(seconds: max(durationSeconds - 0.1, 0), preferredTimescale: 600)
                ].map { NSValue(time: $0) }
                
                var images: [UIImage] = []
                var processed = 0
                
                generator.generateCGImagesAsynchronously(forTimes: times) { _, cgImage, _, _, _ in
                    if let cgImage = cgImage {
                        images.append(UIImage(cgImage: cgImage))
                    }
                    processed += 1
                    if processed == times.count {
                        continuation.resume(returning: images)
                    }
                }
            }
        }
    }
    
    func getVideoFileSize(for asset: PHAsset) async -> Int64 {
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        guard let avAsset = await PHImageManager.default().requestAVAssetAsync(forVideo: asset, options: options),
              let urlAsset = avAsset as? AVURLAsset else {
            return 0
        }
        do {
            let values = try urlAsset.url.resourceValues(forKeys: [.fileSizeKey])
            if let size = values.fileSize {
                return Int64(size)
            }
        } catch {
            print("Error reading file size: \(error)")
        }
        return 0
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

extension PHImageManager {
    func requestUIImage(for asset: PHAsset,
                        targetSize: CGSize,
                        contentMode: PHImageContentMode = .aspectFill,
                        options: PHImageRequestOptions? = nil) async -> UIImage? {
        await withCheckedContinuation { continuation in
            self.requestImage(for: asset,
                              targetSize: targetSize,
                              contentMode: contentMode,
                              options: options) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
    
    func requestAVAssetAsync(forVideo asset: PHAsset,
                             options: PHVideoRequestOptions? = nil) async -> AVAsset? {
        await withCheckedContinuation { continuation in
            self.requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
                continuation.resume(returning: avAsset)
            }
        }
    }
}
