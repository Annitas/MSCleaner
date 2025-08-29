//
//  VideoItem.swift
//  MSCleaner
//
//  Created by Anita Stashevskaya on 13.08.2025.
//

import SwiftUI

struct VideoItem: IdentifiableByLocalID, Codable {
    let id: UUID
    let localIdentifier: String
    let images: [UIImage]
    let creationDate: Date
    var data: Int64
    let duration: TimeInterval
    var isSelected: Bool
    var isBest: Bool

    // MARK: - Init
    init(
        id: UUID = UUID(),
        localIdentifier: String,
        images: [UIImage],
        creationDate: Date,
        data: Int64 = 0,
        duration: TimeInterval,
        isSelected: Bool = true,
        isBest: Bool = false
    ) {
        self.id = id
        self.localIdentifier = localIdentifier
        self.images = images
        self.creationDate = creationDate
        self.data = data
        self.duration = duration
        self.isSelected = isSelected
        self.isBest = isBest
    }

    // MARK: - Codable
    enum CodingKeys: String, CodingKey {
        case id, localIdentifier, images, creationDate, data, duration, isSelected, isBest
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(localIdentifier, forKey: .localIdentifier)

        // UIImage -> Data
        let imageData = images.compactMap { $0.pngData() }
        try container.encode(imageData, forKey: .images)

        try container.encode(creationDate, forKey: .creationDate)
        try container.encode(data, forKey: .data)
        try container.encode(duration, forKey: .duration)
        try container.encode(isSelected, forKey: .isSelected)
        try container.encode(isBest, forKey: .isBest)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        localIdentifier = try container.decode(String.self, forKey: .localIdentifier)

        // Data -> UIImage
        let imageData = try container.decode([Data].self, forKey: .images)
        images = imageData.compactMap { UIImage(data: $0) }

        creationDate = try container.decode(Date.self, forKey: .creationDate)
        data = try container.decode(Int64.self, forKey: .data)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        isSelected = try container.decode(Bool.self, forKey: .isSelected)
        isBest = try container.decode(Bool.self, forKey: .isBest)
    }
}
