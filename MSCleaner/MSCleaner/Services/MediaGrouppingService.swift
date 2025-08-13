//
//  GrouppingService.swift
//  MSCleaner
//
//  Created by Anita Stashevskaya on 13.08.2025.
//

import Photos

final class MediaGrouppingService {
    private let calendar = Calendar.current
    private let imageManager = PHCachingImageManager()
    
    func getGrouppedPhotos(assets: PHFetchResult<PHAsset>) async -> [Date: [PhotoItem]] {
        await withCheckedContinuation { continuation in
            getGrouppedPhotos(assets: assets) { result in
                continuation.resume(returning: result)
            }
        }
    }
    
    func getGrouppedViedos(assets: PHFetchResult<PHAsset>) async -> [TimeInterval: [VideoItem]] {
        await withCheckedContinuation { continuation in
            getGrouppedViedos(assets: assets) { result in
                continuation.resume(returning: result)
            }
        }
    }
    
    private func getGrouppedPhotos(assets: PHFetchResult<PHAsset>,
                                   completion: @escaping ([Date: [PhotoItem]]) -> Void ) {
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
                print("\(number) - \(creationDate)")
                groupedByDate[dateKey, default: []].append(item)
            }
        }
        
        requestImagesGroup.notify(queue: .main) {
            completion(groupedByDate)
            print("IMAGES COMPLETED")
        }
    }
    
    private func getGrouppedViedos(assets: PHFetchResult<PHAsset>,
                                   completion: @escaping ([TimeInterval: [VideoItem]]) -> Void) {
        var groupedByDuration: [TimeInterval: [VideoItem]] = [:]
        let requestVideosGroup = DispatchGroup()
        let requestVideosSemaphore = DispatchSemaphore(value: 2)
        
        let imageRequestOptions = PHImageRequestOptions()
        imageRequestOptions.deliveryMode = .fastFormat
        imageRequestOptions.isSynchronous = true
        
        assets.enumerateObjects { [weak self] asset, number, _ in
            guard let self = self, asset.mediaType == .video else { return }
            let duration = round(asset.duration)
            let fileSize: Int64 = 5 //self.getSizeOfAsset(asset)
            requestVideosGroup.enter()
            requestVideosSemaphore.wait()
            self.imageManager.requestImage(for: asset,
                                           targetSize: CGSize(width: 300, height: 300),
                                           contentMode: .aspectFill,
                                           options: imageRequestOptions) { previewImage, _ in
                defer {
                    requestVideosSemaphore.signal()
                    requestVideosGroup.leave()
                }
                guard let previewImage else { return }
                let videoItem = VideoItem(preview: previewImage,
                                          asset: asset,
                                          duration: duration,
                                          fileSize: fileSize)
                groupedByDuration[duration, default: []].append(videoItem)
                print("Video \(number) - duration \(duration)s - \(fileSize) bytes")
            }
        }
        
        requestVideosGroup.notify(queue: .main) {
            completion(groupedByDuration)
            print("VIDEO GROUPING COMPLETED")
        }
    }
}
