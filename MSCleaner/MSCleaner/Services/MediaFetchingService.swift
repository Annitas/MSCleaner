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
        await withCheckedContinuation { continuation in
            getScreenshots(assets: assets) { result in
                continuation.resume(returning: result)
            }
        }
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
        await withTaskGroup(of: (VideoItem)?.self) { group in
            for asset in videoAssets {
                group.addTask {
                    let duration = round(asset.duration)
                    let fileSize: Int64 = await withCheckedContinuation { [weak self] continuation in
                        self?.getVideoFileSize(for: asset) { size in
                            continuation.resume(returning: size)
                        }
                    }
                    print("filesize: \(fileSize)")
                    let frames = await self.requestPreviewFrames(for: asset, targetSize: CGSize(width: 300, height: 300))
                    guard frames.count == 3 else { return nil }
                    let videoItem = VideoItem(images: frames, asset: asset, duration: duration, fileSize: fileSize)
                    return (videoItem)
                }
            }
            for await result in group {
                if let videoItem = result {
                    groupedByDuration.append(videoItem)
                }
            }
        }
        return [groupedByDuration]
    }
    
    func getGrouppedPhotos(assets: PHFetchResult<PHAsset>) async -> [Date: [PhotoItem]] {
        await withCheckedContinuation { continuation in
            getGrouppedPhotos(assets: assets) { result in
                continuation.resume(returning: result)
            }
        }
    }
    
    func getGrouppedViedos(assets: PHFetchResult<PHAsset>) async -> [TimeInterval: [VideoItem]] {
        var groupedByDuration: [TimeInterval: [VideoItem]] = [:]
        var videoAssets: [PHAsset] = []
        assets.enumerateObjects { asset, _, _ in
            if asset.mediaType == .video {
                videoAssets.append(asset)
            }
        }
        
        await withTaskGroup(of: (TimeInterval, VideoItem)?.self) { group in
            for asset in videoAssets {
                group.addTask {
                    let duration = round(asset.duration)
                    let fileSize: Int64 = 5 // TODO: посчитать реальный размер
                    let frames = await self.requestPreviewFrames(for: asset, targetSize: CGSize(width: 300, height: 300))
                    guard frames.count == 3 else { return nil }
                    let videoItem = VideoItem(images: frames, asset: asset, duration: duration, fileSize: fileSize)
                    return (duration, videoItem)
                }
            }
            for await result in group {
                if let (duration, videoItem) = result {
                    groupedByDuration[duration, default: []].append(videoItem)
                }
            }
        }
        
        print("VIDEO GROUPING COMPLETED")
        return groupedByDuration
    }
    
    private func getScreenshots(assets: PHFetchResult<PHAsset>,
                                completion: @escaping ([Date: [PhotoItem]]) -> Void) {
        let requestOptions = PHImageRequestOptions()
        requestOptions.deliveryMode = .highQualityFormat
        requestOptions.isSynchronous = false
        var groupedByDate: [Date: [PhotoItem]] = [:]
        let requestImagesGroup = DispatchGroup()
        let dateKey = Date()
        assets.enumerateObjects { [weak self] asset, number, _  in
            guard let self = self, let creationDate = asset.creationDate else { return }
            requestImagesGroup.enter()
            self.imageManager.requestImage(for: asset, targetSize: CGSize(width: 300, height: 300),
                                           contentMode: .aspectFill,
                                           options: requestOptions) { image, _ in
                defer {
                    requestImagesGroup.leave()
                }
                guard let image else { return }
                let item = PhotoItem(image: image, creationDate: creationDate, asset: asset)
                groupedByDate[dateKey, default: []].append(item)
            }
        }
        requestImagesGroup.notify(queue: .main) {
            completion(groupedByDate)
            print("IMAGES COMPLETED")
        }
    }
    
    private func getGrouppedPhotos(assets: PHFetchResult<PHAsset>,
                                   completion: @escaping ([Date: [PhotoItem]]) -> Void) {
        let requestOptions = PHImageRequestOptions()
        requestOptions.deliveryMode = .highQualityFormat
        requestOptions.isSynchronous = false
        var groupedByDate: [Date: [PhotoItem]] = [:]
        let requestImagesGroup = DispatchGroup()
        assets.enumerateObjects { [weak self] asset, number, _  in
            guard let self = self, let creationDate = asset.creationDate else { return }
            let dateKey = self.calendar.startOfDay(for: creationDate)
            requestImagesGroup.enter()
            self.imageManager.requestImage(for: asset, targetSize: CGSize(width: 300, height: 300),
                                           contentMode: .aspectFill,
                                           options: requestOptions) { image, _ in
                defer {
                    requestImagesGroup.leave()
                }
                guard let image else { return }
                let item = PhotoItem(image: image, creationDate: creationDate, asset: asset)
                groupedByDate[dateKey, default: []].append(item)
            }
        }
        
        requestImagesGroup.notify(queue: .main) {
            completion(groupedByDate)
            print("IMAGES COMPLETED")
        }
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
    
    func getVideoFileSize(for asset: PHAsset, completion: @escaping (Int64) -> Void) {
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        
        PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
            guard let urlAsset = avAsset as? AVURLAsset else {
                completion(0)
                return
            }
            do {
                let values = try urlAsset.url.resourceValues(forKeys: [.fileSizeKey])
                if let size = values.fileSize {
                    completion(Int64(size))
                } else {
                    completion(0)
                }
            } catch {
                print("Error reading file size: \(error)")
                completion(0)
            }
        }
    }
}
