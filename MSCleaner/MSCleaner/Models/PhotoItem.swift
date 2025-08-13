//
//  ScreenshotItem.swift
//  MSCleaner
//
//  Created by Anita Stashevskaya on 06.08.2025.
//

import SwiftUI
import Photos

struct PhotoItem: Identifiable {
    let id = UUID()
    let image: UIImage
    let creationDate: Date
    let asset: PHAsset
    let data: Int64
    var isSelected: Bool = false
    var isBest: Bool = false
}
