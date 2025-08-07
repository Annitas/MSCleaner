//
//  ScreenshotDuplicateGroup.swift
//  MSCleaner
//
//  Created by Anita Stashevskaya on 07.08.2025.
//

import Foundation

struct ScreenshotDuplicateGroup: Identifiable {
    let id = UUID()
    let duplicates: [ScreenshotItem]
}
