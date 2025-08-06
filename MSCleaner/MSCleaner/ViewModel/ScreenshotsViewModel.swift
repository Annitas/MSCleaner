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
    @Published var sortedDates: [Date] = []
    
    private let calendar = Calendar.current
    private let imageManager = PHCachingImageManager()
    
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
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isSynchronous = false
        
        DispatchQueue.main.async {
            self.groupedImages = [:]
            self.sortedDates = []
        }
        
        assets.enumerateObjects { asset, _, _ in
            guard let creationDate = asset.creationDate else { return }
            
            let dateKey = self.calendar.startOfDay(for: creationDate)
            
            self.imageManager.requestImage(for: asset, targetSize: CGSize(width: 200, height: 400),
                                           contentMode: .aspectFill, options: options) { image, _ in
                guard let image = image else { return }
                let item = ScreenshotItem(image: image, creationDate: creationDate)
                DispatchQueue.main.async {
                    self.addScreenshotWithAnimation(item, to: dateKey)
                }
            }
        }
    }
    
    private func addScreenshotWithAnimation(_ screenshot: ScreenshotItem, to dateKey: Date) {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            if groupedImages[dateKey] == nil {
                groupedImages[dateKey] = []
                insertDateInSortedOrder(dateKey)
            }
            var currentItems = groupedImages[dateKey] ?? []
            let insertIndex = currentItems.firstIndex { $0.creationDate < screenshot.creationDate } ?? currentItems.count
            currentItems.insert(screenshot, at: insertIndex)
            groupedImages[dateKey] = currentItems
        }
    }
    
    private func insertDateInSortedOrder(_ date: Date) {
        let insertIndex = sortedDates.firstIndex { $0 < date } ?? sortedDates.count
        sortedDates.insert(date, at: insertIndex)
    }
}
