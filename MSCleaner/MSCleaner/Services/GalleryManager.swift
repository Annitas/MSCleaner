//
//  GalleryManager.swift
//  MSCleaner
//
//  Created by Anita Stashevskaya on 26.08.2025.
//

import Photos

final class GalleryManager {
    func deletePhotos(for identifiers: [String], completion: @escaping (Bool) -> Void) {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        var assetArray: [PHAsset] = []
        assets.enumerateObjects { asset, _, _ in
            assetArray.append(asset)
        }
        
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets(assetArray as NSArray)
        }) { success, error in
            if success {
                print("✅ Assets deleted")
                completion(success)
            } else {
                print("❌ Failed to delete:", error?.localizedDescription ?? "unknown error")
                completion(success)
            }
        }
    } // TODO: Add cache cleaning
}
