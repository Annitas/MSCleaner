//
//  ScreenshotItem.swift
//  MSCleaner
//
//  Created by Anita Stashevskaya on 06.08.2025.
//

import SwiftUI
import Photos

struct PhotoItem: IdentifiableByLocalID, Codable {
    var id = UUID()
    let localIdentifier: String
    let image: UIImage?
    let creationDate: Date
    var data: Int64 = 0
    var isSelected: Bool = true
    var isBest: Bool = false
    
    init(localIdentifier: String, imageData: UIImage?, creationDate: Date, data: Int64, isSelected: Bool = true, isBest: Bool = false) {
        self.localIdentifier = localIdentifier
        self.image = imageData
        self.creationDate = creationDate
        self.data = data
        self.isSelected = isSelected
        self.isBest = isBest
    }
    
    enum CodingKeys: String, CodingKey {
        case id, localIdentifier, creationDate, data, isSelected, isBest, uiImageData
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(localIdentifier, forKey: .localIdentifier)
        try container.encode(creationDate, forKey: .creationDate)
        try container.encode(data, forKey: .data)
        try container.encode(isSelected, forKey: .isSelected)
        try container.encode(isBest, forKey: .isBest)
        
        if let imageData = image, let data = imageData.pngData() {
            try container.encode(data, forKey: .uiImageData)
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        localIdentifier = try container.decode(String.self, forKey: .localIdentifier)
        creationDate = try container.decode(Date.self, forKey: .creationDate)
        data = try container.decode(Int64.self, forKey: .data)
        isSelected = try container.decode(Bool.self, forKey: .isSelected)
        isBest = try container.decode(Bool.self, forKey: .isBest)
        
        if let imageData = try container.decodeIfPresent(Data.self, forKey: .uiImageData) {
            self.image = UIImage(data: imageData)
        } else {
            self.image = nil
        }
    }
}
