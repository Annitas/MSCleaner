//
//  VideoItem.swift
//  MSCleaner
//
//  Created by Anita Stashevskaya on 13.08.2025.
//

import SwiftUI
import Photos

struct VideoItem: Identifiable {
    let id = UUID()
    let images: [UIImage]
    let asset: PHAsset
    var data: Int64 = 0
    let duration: TimeInterval
    var isBest: Bool = false
    var isSelected: Bool = true
}
