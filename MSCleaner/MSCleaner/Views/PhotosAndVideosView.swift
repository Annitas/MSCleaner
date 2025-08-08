//
//  ContentView.swift
//  MSCleaner
//
//  Created by Anita Stashevskaya on 05.08.2025.
//

import SwiftUI
import CoreData

struct PhotosAndVideosView: View {
    let items = [
        ("Screenshots", "2.2 GB"),
        ("Screen recordings", "2.2 GB"),
        ("Similar photos", "2.2 GB"),
        ("Video duplicates", "2.2 GB"),
    ]
    var body: some View {
        NavigationView {
            List(items, id: \.0) { item in
                NavigationLink(destination: destinationView(for: item.0)) {
                    HStack {
                        Text(item.0)
                            .font(.body)
                        
                        Spacer()
                        
                        Text(item.1)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Photos & videos")
        }
    }
    
    @ViewBuilder
    func destinationView(for itemName: String) -> some View {
        switch itemName {
        case "Screenshots":
            ScreenshotsView(
                title: "Screenshots",
                viewModel: ScreenshotsViewModel(photoService: PhotosService(albumType: .screenshots))
            )
            //        case "Screen recordings":
            //            ScreenRecordingsView()
        case "Similar photos":
            ScreenshotsView(
                title: "Similar photos",
                viewModel: ScreenshotsViewModel(photoService: PhotosService(albumType: .similarPhotos))
            )
            //        case "Video duplicates":
            //            VideoDuplicatesView()
        default:
            Text("Unknown item")
        }
    }
}


#Preview {
    PhotosAndVideosView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
