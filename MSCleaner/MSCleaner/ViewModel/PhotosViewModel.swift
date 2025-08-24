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
    @Published var dataAmount: Int64 = 0
    @Published private(set) var isLoading = false
    @Published private(set) var groupedPhotoDuplicates: [[PhotoItem]] = []
    
    var formattedDeletedDataAmount: String {
        ByteCountFormatter.string(fromByteCount: deletedDataAmount, countStyle: .file)
    }
    
    let photoService: PhotosService
    
    init(photoService: PhotosService) {
        self.photoService = photoService
        
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
        
        photoService.$isLoading
                    .receive(on: DispatchQueue.main)
                    .assign(to: &$isLoading)

    }
    
    @MainActor
    func toggleSelectAll() {
        let shouldSelectAll = selectedItemCount == 0
        for groupIndex in groupedPhotoDuplicates.indices {
            for itemIndex in groupedPhotoDuplicates[groupIndex].indices {
                if groupedPhotoDuplicates[groupIndex][itemIndex].isBest {
                    groupedPhotoDuplicates[groupIndex][itemIndex].isSelected = false
                } else {
                    groupedPhotoDuplicates[groupIndex][itemIndex].isSelected = shouldSelectAll
                }
            }
        }
    }
    
    @MainActor
    func toggleSelection(for item: PhotoItem) {
        guard let (groupIndex, itemIndex) = findItemIndices(for: item) else {
            print("!!! Error toggleSelection: item not found")
            return
        }
        groupedPhotoDuplicates[groupIndex][itemIndex].isSelected.toggle()
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
    
    @MainActor
    func deleteSelected() {
        var assetsToDelete: [PHAsset] = []
        for group in groupedPhotoDuplicates {
            for item in group where item.isSelected {
//                assetsToDelete.append(item.asset)
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
//            let filteredGroup = group.filter { !deletedAssets.contains($0.asset) }
//            if !filteredGroup.isEmpty {
//                filteredGroups.append(filteredGroup)
//            }
        }
        
        groupedPhotoDuplicates = filteredGroups
    }
    
    @MainActor
    private func resetSelection() {
        selectedItemCount = 0
        deletedDataAmount = 0
    }
}
