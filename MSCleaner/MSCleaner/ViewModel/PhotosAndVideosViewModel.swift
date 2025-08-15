//
//  PhotosAndVideosViewModel.swift
//  MSCleaner
//
//  Created by Anita Stashevskaya on 08.08.2025.
//

import SwiftUI
import Combine

final class PhotosAndVideosViewModel: ObservableObject {
    @Published var screenshotsVM: ScreenshotsViewModel
    @Published var similarPhotosVM: ScreenshotsViewModel
    @Published var screenRecordingsVM: ScreenshotsViewModel
    @Published var screenshotsVMdataSize: Int64 = 0
    @Published var similarPhotosVMdataSize: Int64 = 0
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        let screenshotsService = PhotosService(albumType: .screenshots)
        let similarPhotosService = PhotosService(albumType: .similarPhotos)
        let screenRecordingsService = PhotosService(albumType: .screenRecordings)
        
        self.screenshotsVM = ScreenshotsViewModel(photoService: screenshotsService)
        self.similarPhotosVM = ScreenshotsViewModel(photoService: similarPhotosService)
        self.screenRecordingsVM = ScreenshotsViewModel(photoService: screenRecordingsService)
        
        screenshotsVM.$dataAmount
            .receive(on: DispatchQueue.main)
            .assign(to: \.screenshotsVMdataSize, on: self)
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

