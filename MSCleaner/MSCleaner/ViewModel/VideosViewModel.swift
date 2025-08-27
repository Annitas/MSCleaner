//
//  VideosViewModel.swift
//  MSCleaner
//
//  Created by Anita Stashevskaya on 17.08.2025.
//

import SwiftUI
import Photos
import Combine

final class VideosViewModel: ObservableObject {
    @Published private(set) var groupedVideoDuplicates: [[VideoItem]] = []
    @Published var selectedItemCount = 0
    @Published var deletedDataAmount: Int64 = 0
    @Published var dataAmount: Int64 = 0
    @Published private(set) var isLoading = false
    
    private var cancellables = Set<AnyCancellable>()
    private let videoService: VideoService
    
    var formattedDeletedDataAmount: String {
        ByteCountFormatter.string(fromByteCount: deletedDataAmount, countStyle: .file)
    }
    
    init(videoService: VideoService) {
        self.videoService = videoService
        
        videoService.$grouppedDuplicatedVideos
            .receive(on: DispatchQueue.main)
            .assign(to: &$groupedVideoDuplicates)
        
        $groupedVideoDuplicates
            .map { $0.flatMap { $0 } }
            .map { items in
                items
                    .filter { $0.isSelected }
                    .map(\.data)
                    .reduce(0, +)
            }
            .assign(to: &$deletedDataAmount)
        
        $groupedVideoDuplicates
            .map { $0.flatMap { $0 }.filter { $0.isSelected }.count }
            .assign(to: &$selectedItemCount)
        
        videoService.$isLoading
                    .receive(on: DispatchQueue.main)
                    .assign(to: &$isLoading)
    }
    
    @MainActor
    func toggleSelectAll() {
        let shouldSelectAll = selectedItemCount == 0
        for groupIndex in groupedVideoDuplicates.indices {
            for itemIndex in groupedVideoDuplicates[groupIndex].indices {
                if groupedVideoDuplicates[groupIndex][itemIndex].isBest {
                    groupedVideoDuplicates[groupIndex][itemIndex].isSelected = false
                } else {
                    groupedVideoDuplicates[groupIndex][itemIndex].isSelected = shouldSelectAll
                }
            }
        }
    }
    
    @MainActor
    func toggleSelection(for item: VideoItem) {
        guard let (groupIndex, itemIndex) = findItemIndices(for: item) else {
            print("!!! Error toggleSelection: video not found")
            return
        }
        
        groupedVideoDuplicates[groupIndex][itemIndex].isSelected.toggle()
    }
    
    private func findItemIndices(for item: VideoItem) -> (Int, Int)? {
        for (groupIndex, group) in groupedVideoDuplicates.enumerated() {
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
        var assetsToDelete: [String] = []
        for group in groupedVideoDuplicates {
            for item in group where item.isSelected {
                assetsToDelete.append(item.localIdentifier)
            }
        }
        guard !assetsToDelete.isEmpty else { return }
        GalleryManager().deletePhotos(for: assetsToDelete) { [weak self] isSuccess in
            if isSuccess {
                self?.removeDeletedItems(assetsToDelete)
                self?.resetSelection()
            }
        }
    }
    
    @MainActor
    private func removeDeletedItems(_ deletedAssets: [String]) {
        var filteredGroups: [[VideoItem]] = []
        
        for group in groupedVideoDuplicates {
            let filteredGroup = group.filter { !deletedAssets.contains($0.localIdentifier) }
            if !filteredGroup.isEmpty {
                filteredGroups.append(filteredGroup)
            }
        }
        groupedVideoDuplicates = filteredGroups
    }
    
    @MainActor
    private func resetSelection() {
        selectedItemCount = 0
        deletedDataAmount = 0
    }
}
