//
//  ScreenshotsViewModel.swift
//  MSCleaner
//
//  Created by Anita Stashevskaya on 06.08.2025.
//

import SwiftUI
import Photos
import Combine

final class PhotosViewModel: ObservableObject {
    @Published var selectedItemCount = 0
    @Published var deletedDataAmount: Int64 = 0
    @Published private(set) var groupedPhotoDuplicates: [[PhotoItem]] = []
    @Published var dataAmount: Int64 = 0
    
    private let dataSizeQueue = DispatchQueue(label: "data.size.calculation", attributes: .concurrent)
    private let updateQueue = DispatchQueue(label: "data.updates", attributes: .concurrent)
    private var cancellables = Set<AnyCancellable>()
    
    var formattedDeletedDataAmount: String {
        ByteCountFormatter.string(fromByteCount: deletedDataAmount, countStyle: .file)
    }
    
    let photoService: PhotosService
    
    init(photoService: PhotosService) {
        self.photoService = photoService
        
        photoService.$assetSizes
            .receive(on: DispatchQueue.main)
            .assign(to: &$dataAmount)
        
        photoService.$groupedDuplicatedPhotos
            .receive(on: DispatchQueue.main)
            .assign(to: &$groupedPhotoDuplicates)
        
        $groupedPhotoDuplicates
            .map { $0.flatMap { $0 } }
            .map { items in
                items
                    .filter { $0.isSelected }
                    .map(\.data)
                    .reduce(0, +)
            }
            .assign(to: &$deletedDataAmount)
        
        $groupedPhotoDuplicates
            .map { $0.flatMap { $0 }.filter { $0.isSelected }.count }
            .assign(to: &$selectedItemCount)
    }
    
    @MainActor
    func toggleSelectAll() {
        let shouldSelectAll = selectedItemCount == 0
        
        selectedItemCount = 0
        deletedDataAmount = 0
        
        for groupIndex in groupedPhotoDuplicates.indices {
            for itemIndex in groupedPhotoDuplicates[groupIndex].indices {
                let item = groupedPhotoDuplicates[groupIndex][itemIndex]
                
                if item.isBest {
                    groupedPhotoDuplicates[groupIndex][itemIndex].isSelected = false
                    continue
                }
                
                groupedPhotoDuplicates[groupIndex][itemIndex].isSelected = shouldSelectAll
                if shouldSelectAll {
                    selectedItemCount += 1
                    deletedDataAmount += getAssetFileSize(for: item.asset)
                }
            }
        }
        
        objectWillChange.send()
    }
    
    @MainActor
    func toggleSelection(for item: PhotoItem) {
        guard let (groupIndex, itemIndex) = findItemIndices(for: item) else {
            print("!!! Error toggleSelection: item not found")
            return
        }
        
        groupedPhotoDuplicates[groupIndex][itemIndex].isSelected.toggle()
        
        let isSelected = groupedPhotoDuplicates[groupIndex][itemIndex].isSelected
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
    
    private func findItemIndices(for item: PhotoItem) -> (Int, Int)? {
        for (groupIndex, group) in groupedPhotoDuplicates.enumerated() {
            for (itemIndex, duplicate) in group.enumerated() {
                if duplicate.id == item.id {
                    return (groupIndex, itemIndex)
                }
            }
        }
        return nil
    }
    
    func calculateDataAmount() {
        guard !groupedPhotoDuplicates.isEmpty else {
            updateDataAmount(0)
            return
        }
        
        dataSizeQueue.async { [weak self] in
            guard let self = self else { return }
            
            var totalSize: Int64 = 0
            
            for group in self.groupedPhotoDuplicates {
                for item in group {
                    totalSize += self.getAssetFileSize(for: item.asset)
                }
            }
            
            self.updateDataAmount(totalSize)
        }
    }
    
    private func updateDataAmount(_ newValue: Int64) {
        updateQueue.async(flags: .barrier) { [weak self] in
            DispatchQueue.main.async {
                self?.dataAmount = newValue
            }
        }
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
        for group in groupedPhotoDuplicates {
            for item in group where item.isSelected {
                assetsToDelete.append(item.asset)
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
        var filteredGroups: [[PhotoItem]] = []
        
        for group in groupedPhotoDuplicates {
            let filteredGroup = group.filter { !deletedAssets.contains($0.asset) }
            if !filteredGroup.isEmpty {
                filteredGroups.append(filteredGroup)
            }
        }
        
        groupedPhotoDuplicates = filteredGroups
    }
    
    @MainActor
    private func resetSelection() {
        selectedItemCount = 0
        deletedDataAmount = 0
    }
}
