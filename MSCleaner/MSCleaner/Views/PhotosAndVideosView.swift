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
                isLoading: viewModel.screenshotsVM.isLoading
            ),
            MediaTitle(
                title: "Screen recordings",
                size: viewModel.screenRecordingsSize,
                isLoading: viewModel.screenRecordingsVM.isLoading
            ),
            MediaTitle(
                title: "Similar photos",
                size: viewModel.similarPhotosSize,
                isLoading: viewModel.similarPhotosVM.isLoading
            ),
            MediaTitle(
                title: "Video duplicates",
                size: viewModel.similarVideosSize,
                isLoading: viewModel.similarVideosVM.isLoading
            )
        ]
    }
    
    var body: some View {
        NavigationView {
            List {
                mediaRow(title: items[0].title, size: items[0].size, isLoading: items[0].isLoading)
                mediaRow(title: items[1].title, size: items[1].size, isLoading: items[1].isLoading)
                mediaRow(title: items[2].title, size: items[2].size, isLoading: items[2].isLoading)
                mediaRow(title: items[3].title, size: items[3].size, isLoading: items[3].isLoading)
            }
            .navigationTitle("Photos & videos")
        }
    }
    
    func mediaRow(title: String, size: String, isLoading: Bool) -> some View {
        NavigationLink(destination: destinationView(for: title)) {
            HStack {
                Text(title)
                    .font(.body)
                
                Spacer()
                
                Text(size)
                    .font(.caption)
                    .foregroundColor(isLoading ? .blue : .secondary)
            }
            .padding(.vertical, 4)
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
        default:
            Text("Unknown item")
        }
    }
}


//#Preview {
//    PhotosAndVideosView()
//}
