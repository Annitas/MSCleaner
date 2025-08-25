//
//  ScreenshotsView.swift
//  MSCleaner
//
//  Created by Anita Stashevskaya on 05.08.2025.
//

import SwiftUI
import Photos

struct PhotosView: View {
    @State var title: String
    @StateObject var viewModel: PhotosViewModel
    
    var photos: [PhotoItem] {
        viewModel.groupedPhotoDuplicates.flatMap { $0 }
    }
    
    var totalSizeGB: Double {
        let totalBytes = photos.reduce(0) { $0 + $1.data }
        return Double(totalBytes) / (1024 * 1024 * 1000)
    }
    
    var header: some View {
        HStack {
            Text("\(photos.count) photos (\(String(format: "%.2f", totalSizeGB)) GB)")
            Spacer()
            Button(viewModel.selectedItemCount == 0 ? "Select all" : "Deselect all") {
                viewModel.toggleSelectAll()
            }
        }
        .padding(16)
    }
    
    var body: some View {
        VStack {
            header
            
            ScrollView {
                LazyVStack(spacing: 20) {
                    ForEach(Array(viewModel.groupedPhotoDuplicates.enumerated()), id: \.offset) { groupIndex, group in
                        GroupView(group: group, viewModel: viewModel)
                    }
                }
            }
            
            deleteButton
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8),
                   value: viewModel.groupedPhotoDuplicates.count)
        .navigationTitle(title)
    }
    
    private var deleteButton: some View {
        Button(action: {
            viewModel.deleteSelected()
        }) {
            HStack(spacing: 8) {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(width: 20, height: 20)
                        .padding(8)
                }
                
                Text("Delete \(viewModel.selectedItemCount) photos (\(viewModel.formattedDeletedDataAmount))")
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(Color.blue)
            .cornerRadius(8)
        }
        .padding(.horizontal)
    }
}

struct GroupView: View {
    let group: [PhotoItem]
    let viewModel: PhotosViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(group.count) items")
                .font(.headline)
                .fontWeight(.semibold)
                .padding(.horizontal, 16)
            
            LazyVGrid(columns: [GridItem(spacing: 16), GridItem(spacing: 16)], spacing: 8) {
                ForEach(group, id: \.id) { item in
                    PhotoCell(item: item, viewModel: viewModel)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }
}


struct PhotoCell: View {
    let item: PhotoItem
    let viewModel: PhotosViewModel
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Rectangle()
                .overlay {
                    if let image = item.image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .clipped()
                    } else {
                        Color.gray.opacity(0.2)
                    }
                }
                .frame(width: 200, height: 200)
                .contentShape(Rectangle())
                .onTapGesture {
                    viewModel.toggleSelection(for: item)
                }
                .cornerRadius(8)
                .shadow(radius: 3)
            
            if item.isBest {
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundColor(.blue)
                        .shadow(radius: 2)
                    Text("Best")
                        .fontWeight(.medium)
                        .foregroundStyle(.blue)
                }
                .padding(6)
                .background(.white.opacity(0.8))
                .cornerRadius(6)
                .padding(8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            
            ZStack {
                Circle()
                    .fill(item.isSelected ? Color.blue : Color.white.opacity(0.7))
                    .frame(width: 24, height: 24)
                    .overlay(
                        Circle().stroke(Color.white, lineWidth: 2)
                    )
                
                if item.isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.white)
                        .font(.system(size: 12, weight: .bold))
                }
            }
            .shadow(radius: 3)
            .padding(6)
        }
    }
}


//#Preview {
//    PhotosView(title: "View", viewModel: PhotosViewModel(photoService: PhotosService(albumType: .screenshots)))
//}
