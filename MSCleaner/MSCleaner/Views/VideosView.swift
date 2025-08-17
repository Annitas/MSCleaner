//
//  VideosView.swift
//  MSCleaner
//
//  Created by Anita Stashevskaya on 15.08.2025.
//

import SwiftUI
import Photos

import SwiftUI
import Photos

struct VideosView: View {
    @State var title: String
    @StateObject var viewModel: VideosViewModel
    
    var body: some View {
        let videos = viewModel.groupedVideoDuplicates.flatMap { $0 }
        let totalSizeGB = Double(videos.reduce(0) { $0 + $1.fileSize }) / (1024 * 1024 * 1000)
        
        VStack {
            HStack {
                Text("\(videos.count) videos (\(String(format: "%.2f", totalSizeGB)) GB)")
                Spacer()
                Button(viewModel.selectedItemCount == 0 ? "Select all" : "Deselect all") {
//                    viewModel.toggleSelectAll()
                }
            }
            .padding(16)
            
            ScrollView {
                LazyVStack(spacing: 20) {
                    ForEach(Array(viewModel.groupedVideoDuplicates.enumerated()), id: \.offset) { groupIndex, group in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(group.count) items")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 16)
                            
                            LazyVGrid(columns: [
                                GridItem(spacing: 16),
                                GridItem(spacing: 16)
                            ], spacing: 8) {
                                ForEach(group, id: \.id) { item in
                                    ZStack(alignment: .bottomTrailing) {
                                        Rectangle()
                                            .overlay {
                                                if let preview = item.images.first {
                                                    Image(uiImage: preview)
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fill)
                                                        .clipped()
                                                } else {
                                                    Color.gray
                                                }
                                            }
                                            .frame(width: 200, height: 200)
                                            .contentShape(Rectangle())
                                            .onTapGesture {
//                                                viewModel.toggleSelection(for: item)
                                            }
                                            .cornerRadius(8)
                                            .shadow(radius: 3)
                                        
                                        // Видео иконка + длительность
                                        VStack(alignment: .leading) {
                                            Spacer()
                                            HStack {
                                                Image(systemName: "video.fill")
                                                    .foregroundColor(.white)
                                                Text(formatDuration(item.duration))
                                                    .foregroundColor(.white)
                                                    .font(.caption)
                                                    .bold()
                                            }
                                            .padding(6)
                                            .background(Color.black.opacity(0.6))
                                            .cornerRadius(6)
                                        }
                                        .padding(8)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                        
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
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
                        }
                    }
                }
            }
            
//            Button(action: {
//                viewModel.deleteSelected()
//            }) {
//                Text("Delete \(viewModel.selectedItemCount) videos (\(viewModel.formattedDeletedDataAmount))")
//                    .foregroundColor(.white)
//                    .frame(maxWidth: .infinity, minHeight: 56)
//                    .background(Color.blue)
//                    .cornerRadius(8)
//            }
//            .padding(.horizontal)
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: viewModel.groupedVideoDuplicates.count)
        .navigationTitle(title)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
