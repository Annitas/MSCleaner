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
    let duration: TimeInterval
    let fileSize: Int64
    var isSelected: Bool = false
}
