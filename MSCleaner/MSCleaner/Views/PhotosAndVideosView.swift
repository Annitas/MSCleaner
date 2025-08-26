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
                size: viewModel.screenshotsSize,
                isLoading: viewModel.isScreenshotsLoading
            ),
            MediaTitle(
                title: "Screen recordings",
                size: viewModel.screenRecordingsSize,
                isLoading: viewModel.isScreenRecordingsLoading
            ),
            MediaTitle(
                title: "Similar photos",
                size: viewModel.similarPhotosSize,
                isLoading: viewModel.isSimilarPhotosLoading
            ),
            MediaTitle(
                title: "Video duplicates",
                size: viewModel.similarVideosSize,
                isLoading: viewModel.isSimilarVideosLoading
            ),
            MediaTitle(
                title: "Large videos",
                size: viewModel.largeVideosSize,
                isLoading: viewModel.isLargeVideosLoading
            )
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
                                .foregroundColor(item.isLoading ? .blue : .secondary)
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
            PhotosView(
                title: "Screenshots",
                viewModel: viewModel.screenshotsVM
            )
        case "Screen recordings":
            VideosView(
                title: "Screen recordings",
                viewModel: viewModel.screenRecordingsVM
            )
        case "Similar photos":
            PhotosView(
                title: "Similar photos",
                viewModel: viewModel.similarPhotosVM
            )
        case "Video duplicates":
            VideosView(
                title: "Video duplicates",
                viewModel: viewModel.similarVideosVM
            )
        case "Large videos":
            VideosView(title: "Large videos",
                       viewModel: viewModel.largeVideosVM
            )
        default:
            Text("Unknown item")
        }
    }
}


//#Preview {
//    PhotosAndVideosView()
//}
