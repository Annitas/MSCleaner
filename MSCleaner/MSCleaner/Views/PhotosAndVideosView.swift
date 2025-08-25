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
                size: viewModel.screenshotsSize
            ),
            MediaTitle(
                title: "Screen recordings",
                size: viewModel.screenRecordingsSize
            ),
            MediaTitle(
                title: "Similar photos",
                size: viewModel.similarPhotosSize
            ),
            MediaTitle(
                title: "Video duplicates",
                size: viewModel.similarVideosSize
            )
        ]
    }
    
    var body: some View {
        NavigationView {
            List {
                mediaRow(title: items[0].title, size: items[0].size, isLoading: viewModel.screenshotsVM.isLoading)
                mediaRow(title: items[1].title, size: items[1].size, isLoading: viewModel.screenRecordingsVM.isLoading)
                mediaRow(title: items[2].title, size: items[2].size, isLoading: viewModel.similarPhotosVM.isLoading)
                mediaRow(title: items[3].title, size: items[3].size, isLoading: viewModel.similarVideosVM.isLoading)
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
