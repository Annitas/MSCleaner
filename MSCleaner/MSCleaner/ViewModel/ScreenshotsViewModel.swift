//
//  ScreenshotsViewModel.swift
//  MSCleaner
//
//  Created by Anita Stashevskaya on 06.08.2025.
//

import SwiftUI
import Photos
import Combine

final class ScreenshotsViewModel: ObservableObject {
    @Published var selectedItemCount = 0
    @Published var deletedDataAmount: Int64 = 0
    @Published private(set) var groupedDuplicates: [Date: [ScreenshotDuplicateGroup]] = [:]
    @Published private(set) var sortedDates: [Date] = []
    
    private let sortedDatesQueue = DispatchQueue(label: "sortedDatesQueue", attributes: .concurrent)
    private var cancellables = Set<AnyCancellable>()
    let photoService: PhotosService
    
    init(photoService: PhotosService) {
        self.photoService = photoService
        
        photoService.$groupedDuplicates
            .receive(on: DispatchQueue.main)
            .assign(to: &$groupedDuplicates)
        
        photoService.$sortedDates
            .receive(on: DispatchQueue.main)
            .assign(to: &$sortedDates)
    }
    
    func load() {
        photoService.fetchScreenshots()
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
    
    @MainActor
    func toggleSelectAll() {
        let shouldSelectAll = selectedItemCount == 0
        
        selectedItemCount = 0
        deletedDataAmount = 0
        
        for (date, groups) in groupedDuplicates {
            for (groupIndex, group) in groups.enumerated() {
                for (itemIndex, var item) in group.duplicates.enumerated() {
                    if item.isBest {
                        groupedDuplicates[date]![groupIndex].duplicates[itemIndex].isSelected = false
                        continue
                    }
                    groupedDuplicates[date]![groupIndex].duplicates[itemIndex].isSelected = shouldSelectAll
                    if shouldSelectAll {
                        selectedItemCount += 1
                        deletedDataAmount += getAssetFileSize(for: item.asset)
                    }
                }
            }
        }
        
        objectWillChange.send()
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
        
        // Собираем список удаляемых ассетов
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
                guard let self = self else { return }
                
                if success {
                    self.removeDeletedItems(assetsToDelete)
                    self.resetSelection()
                } else if let error = error {
                    print("!!! Error deleteSelected \(error)")
                }
            }
        }
    }
    
    @MainActor
    private func removeDeletedItems(_ deletedAssets: [PHAsset]) {
        var newGrouped: [Date: [ScreenshotDuplicateGroup]] = [:]
        
        for (date, groups) in groupedDuplicates {
            var filteredGroups: [ScreenshotDuplicateGroup] = []
            
            for var group in groups {
                group.duplicates.removeAll { deletedAssets.contains($0.asset) }
                if !group.duplicates.isEmpty {
                    filteredGroups.append(group)
                }
            }
            
            if !filteredGroups.isEmpty {
                newGrouped[date] = filteredGroups
            }
        }
        
        groupedDuplicates = newGrouped
        sortedDates = sortedDates.filter { newGrouped.keys.contains($0) }
    }
    
    @MainActor
    private func resetSelection() {
        selectedItemCount = 0
        deletedDataAmount = 0
    }
}
