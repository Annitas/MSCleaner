//
//  PhotosAndVideosViewModel.swift
//  MSCleaner
//
//  Created by Anita Stashevskaya on 08.08.2025.
//

import SwiftUI
import Combine

protocol DataCalculateable {
    var dataAmount: Int64 { get set }
}

final class PhotosAndVideosViewModel: ObservableObject {
    @Published var screenshotsVM: PhotosViewModel
    @Published var similarPhotosVM: PhotosViewModel
    @Published var screenRecordingsVM: VideosViewModel
    @Published var similarVideosVM: VideosViewModel
    
    @Published private(set) var screenshotsSize: String = ""
    @Published private(set) var similarPhotosSize: String = ""
    @Published private(set) var screenRecordingsSize: String = ""
    @Published private(set) var similarVideosSize: String = ""
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        let screenshotsService = PhotosService(albumType: .screenshots)
        let similarPhotosService = PhotosService(albumType: .similarPhotos)
        let screenRecordingsService = PhotosService(albumType: .screenRecordings)
        let similarVideosService = PhotosService(albumType: .videoDuplicates)
        
        self.screenshotsVM = PhotosViewModel(photoService: screenshotsService)
        self.similarPhotosVM = PhotosViewModel(photoService: similarPhotosService)
        self.screenRecordingsVM = VideosViewModel(photoService: screenRecordingsService)
        self.similarVideosVM = VideosViewModel(photoService: similarVideosService)
        
        bindService(screenshotsService, to: \.screenshotsSize)
        bindService(similarPhotosService, to: \.similarPhotosSize)
        bindService(screenRecordingsService, to: \.screenRecordingsSize)
        bindService(similarVideosService, to: \.similarVideosSize)
    }
    
    private func bindService(_ service: PhotosService, to keyPath: ReferenceWritableKeyPath<PhotosAndVideosViewModel, String>) {
        service.$assetSizes
            .map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) }
            .receive(on: DispatchQueue.main)
            .assign(to: keyPath, on: self)
            .store(in: &cancellables)
    }
}

