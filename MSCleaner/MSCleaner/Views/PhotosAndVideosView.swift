//
//  ContentView.swift
//  MSCleaner
//
//  Created by Anita Stashevskaya on 05.08.2025.
//

import SwiftUI
import CoreData

struct PhotosAndVideosView: View {
    @StateObject var viewModel = PhotosAndVideosViewModel()
    
    private var items: [MediaTitle] {
        [
            MediaTitle(
                title: "Screenshots",
                size: viewModel.formattedScreenshotsDataSize
            ),
            MediaTitle(
                title: "Screen recordings",
                size: "2.2 GB" // TODO: Заменить на динамическое значение
            ),
            MediaTitle(
                title: "Similar photos",
                size: viewModel.formattedSimilarPhotosDataSize
            ),
            MediaTitle(
                title: "Video duplicates",
                size: "2.2 GB" // TODO: Заменить на динамическое значение
            ),
        ]
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(items, id: \.title) { item in
                    NavigationLink(destination: destinationView(for: item.title)) {
                        HStack {
                            Text(item.title)
                                .font(.body)
                            
                            Spacer()
                            
                            Text(item.size)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
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
                viewModel: viewModel.screenshotsVM
            )
            //        case "Screen recordings":
            //            ScreenRecordingsView()
        case "Similar photos":
            ScreenshotsView(
                title: "Similar photos",
                viewModel: viewModel.similarPhotosVM
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
