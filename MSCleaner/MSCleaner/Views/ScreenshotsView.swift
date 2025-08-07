//
//  ScreenshotsView.swift
//  MSCleaner
//
//  Created by Anita Stashevskaya on 05.08.2025.
//

import SwiftUI
import Photos

struct ScreenshotsView: View {
    @StateObject private var viewModel = ScreenshotsViewModel()
    
    var body: some View {
        let photos = viewModel.groupedDuplicates.values.flatMap { $0.flatMap { $0.duplicates } }
        let resources = photos.flatMap { PHAssetResource.assetResources(for: $0.asset) }
            .filter { $0.type == .photo }
            .reduce(0) { $0 + ($1.value(forKey: "fileSize") as? Int64 ?? 0) }
        let totalSizeGB = Double(resources) / (1024 * 1024 * 1000)

        VStack(alignment: .leading) {
            Text("\(photos.count) photos (\(String(format: "%.2f", totalSizeGB)) GB)")
                .padding(16)
            ScrollView {
                LazyVStack(spacing: 20) {
                    ForEach(viewModel.sortedDates, id: \.self) { date in
                        if let groups = viewModel.groupedDuplicates[date] {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("\(groups.flatMap { $0.duplicates }.count) items")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 16)
                                
                                ForEach(groups) { group in
                                    LazyVGrid(columns: [
                                        GridItem(spacing: 16),
                                        GridItem(spacing: 16)
                                    ], spacing: 8) {
                                        ForEach(group.duplicates, id: \.id) { item in
                                            ZStack(alignment: .bottomTrailing) {
                                                Rectangle()
                                                    .overlay(content: {
                                                        Image(uiImage: item.image)
                                                            .resizable()
                                                            .aspectRatio(contentMode: .fill)
                                                        
                                                            .clipped()
                                                        
                                                    })
                                                    .frame(width: 200, height: 200)
                                                    .contentShape(Rectangle())
                                                    .onTapGesture {
                                                        viewModel.toggleSelection(for: item)
                                                    }
                                                    .cornerRadius(8)
                                                    .shadow(radius: 3)
                                                
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
                }
            }
            
            Button(action: {
                viewModel.deleteSelected()
            }) {
                Text("Delete \(viewModel.selectedItemCount) photos")
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
            .padding(.horizontal)
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: viewModel.sortedDates.count)
        .navigationTitle("Similar Photos")
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: date)
    }
}

//#Preview {
//    ScreenshotsView()
//}
