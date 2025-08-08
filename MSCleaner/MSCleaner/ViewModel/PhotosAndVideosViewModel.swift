//
//  PhotosAndVideosViewModel.swift
//  MSCleaner
//
//  Created by Anita Stashevskaya on 08.08.2025.
//

import SwiftUI

final class PhotosAndVideosViewModel: ObservableObject {
    @Published var screenshotsVM: ScreenshotsViewModel
    @Published var similarPhotosVM: ScreenshotsViewModel
    
    init() {
        let screenshotsService = PhotosService(albumType: .screenshots)
        let similarPhotosService = PhotosService(albumType: .similarPhotos)
        
        self.screenshotsVM = ScreenshotsViewModel(photoService: screenshotsService)
        self.similarPhotosVM = ScreenshotsViewModel(photoService: similarPhotosService)
    }
}

