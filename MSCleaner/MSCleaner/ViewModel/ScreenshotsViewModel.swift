//
//  ScreenshotsViewModel.swift
//  MSCleaner
//
//  Created by Anita Stashevskaya on 06.08.2025.
//

import SwiftUI
import Photos

final class ScreenshotsViewModel: ObservableObject {
    @Published var groupedImages: [Date: [ScreenshotItem]] = [:]
    
    init() {
        fetchScreenshots()
    }
    
    func fetchScreenshots() {
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized || status == .limited else { return }
            
            let fetchOptions = PHFetchOptions()
            let screenshotsAlbum = PHAssetCollection.fetchAssetCollections(
                with: .smartAlbum,
                subtype: .smartAlbumScreenshots,
                options: nil
            )
            
            guard let collection = screenshotsAlbum.firstObject else { return }
            
            let assets = PHAsset.fetchAssets(in: collection, options: fetchOptions)
            
            let imageManager = PHCachingImageManager()
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isSynchronous = false
            
            var tempScreenshots: [ScreenshotItem] = []
            let dispatchGroup = DispatchGroup()
            
            assets.enumerateObjects { asset, _, _ in
                dispatchGroup.enter()
                imageManager.requestImage(
                    for: asset,
                    targetSize: CGSize(width: 200, height: 400),
                    contentMode: .aspectFill,
                    options: options
                ) { image, _ in
                    defer { dispatchGroup.leave() }
                    
                    if let image = image, let creationDate = asset.creationDate {
                        let item = ScreenshotItem(
                            image: image,
                            creationDate: creationDate
                        )
                        tempScreenshots.append(item)
                    }
                }
            }
            dispatchGroup.notify(queue: .main) {
                self.groupImagesByDate(tempScreenshots)
            }
        }
    }
    
    private func groupImagesByDate(_ screenshots: [ScreenshotItem]) {
        let calendar = Calendar.current
        
        let grouped = Dictionary(grouping: screenshots) { screenshot in
            calendar.startOfDay(for: screenshot.creationDate)
        }
        
        var sortedGrouped: [Date: [ScreenshotItem]] = [:]
        for (date, items) in grouped {
            sortedGrouped[date] = items.sorted { $0.creationDate > $1.creationDate }
        }
        
        self.groupedImages = sortedGrouped
    }
}
