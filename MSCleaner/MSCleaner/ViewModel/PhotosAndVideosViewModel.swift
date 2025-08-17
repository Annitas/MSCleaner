//
//  PhotosAndVideosViewModel.swift
//  MSCleaner
//
//  Created by Anita Stashevskaya on 08.08.2025.
//

import SwiftUI
import Combine

final class PhotosAndVideosViewModel: ObservableObject {
    @Published var screenshotsVM: PhotosViewModel
    @Published var similarPhotosVM: PhotosViewModel
    @Published var screenRecordingsVM: VideosViewModel
    @Published var similarVideosVM: VideosViewModel
    @Published var screenshotsVMdataSize: Int64 = 0
    @Published var similarPhotosVMdataSize: Int64 = 0
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        let screenshotsService = PhotosService(albumType: .screenshots)
        let similarPhotosService = PhotosService(albumType: .similarPhotos)
        let screenRecordingsService = PhotosService(albumType: .screenRecordings)
        let similarVideos = PhotosService(albumType: .videoDuplicates)
        
        self.screenshotsVM = PhotosViewModel(photoService: screenshotsService)
        self.similarPhotosVM = PhotosViewModel(photoService: similarPhotosService)
        self.screenRecordingsVM = VideosViewModel(photoService: screenRecordingsService)
        self.similarVideosVM = VideosViewModel(photoService: similarVideos)
        
        screenshotsVM.$dataAmount
            .receive(on: DispatchQueue.main)
            .assign(to: \.similarPhotosVMdataSize, on: self)
            .store(in: &cancellables)
        
        similarPhotosVM.$dataAmount
            .receive(on: DispatchQueue.main)
            .assign(to: \.similarPhotosVMdataSize, on: self)
            .store(in: &cancellables)
    }
    
    var formattedScreenshotsDataSize: String {
        ByteCountFormatter.string(fromByteCount: screenshotsVMdataSize, countStyle: .file)
    }
    
    var formattedSimilarPhotosDataSize: String {
        ByteCountFormatter.string(fromByteCount: similarPhotosVMdataSize, countStyle: .file)
    }
}

