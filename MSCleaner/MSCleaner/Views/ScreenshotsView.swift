//
//  ScreenshotsView.swift
//  MSCleaner
//
//  Created by Anita Stashevskaya on 05.08.2025.
//

import SwiftUI

struct ScreenshotsView: View {
    @StateObject private var viewModel = ScreenshotsViewModel()
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                ForEach(viewModel.sortedDates, id: \.self) { date in
                    if let groups = viewModel.groupedDuplicates[date] {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(formatDate(date))
                                .font(.headline)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 16)
                            
                            ForEach(groups) { group in
                                LazyVGrid(columns: [
                                    GridItem(spacing: 16),
                                    GridItem(spacing: 16)
                                ], spacing: 8) {
                                    ForEach(group.duplicates, id: \.id) { item in
                                        Image(uiImage: item.image)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 200, height: 200)
                                            .clipped()
                                            .cornerRadius(8)
                                            .shadow(radius: 3)
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
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: viewModel.sortedDates.count)
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
