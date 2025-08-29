//
//  GalleryManager.swift
//  MSCleaner
//
//  Created by Anita Stashevskaya on 26.08.2025.
//

import Photos

final class GalleryManager {
    func hasAccessToGallery() -> Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        return status == .authorized || status == .limited
    }
    
    func calculateGallerySize() async -> Double {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var totalSize: Double = 0
                let assets = PHAsset.fetchAssets(with: nil)
                
                assets.enumerateObjects { asset, _, _ in
                    let resources = PHAssetResource.assetResources(for: asset)
                    for resource in resources {
                        if let unsignedInt64 = resource.value(forKey: "fileSize") as? CLong {
                            totalSize += Double(unsignedInt64)
                        }
                    }
                }
                
                let sizeInGB = totalSize * pow(10.0, -9.0)
                continuation.resume(returning: sizeInGB)
            }
        }
    }
    
    func deletePhotos(for identifiers: [String], albumType: AlbumType, completion: @escaping (Bool) -> Void) {
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
//                CacheService().deletePhotosFromCache(for: identifiers, albumType: albumType)
                completion(success)
            } else {
                print("❌ Failed to delete:", error?.localizedDescription ?? "unknown error")
                completion(success)
            }
        }
    } // TODO: Add cache cleaning
}
