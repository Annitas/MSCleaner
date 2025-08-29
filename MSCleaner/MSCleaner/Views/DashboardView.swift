//
//  DashboardView.swift
//  MSCleaner
//
//  Created by Anita Stashevskaya on 26.08.2025.
//

import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    
    private var items: [MediaTitle] {
        [
            MediaTitle(imageName: "photo.on.rectangle",
                       title: "Photos & Videos",
                       size: viewModel.gallerySize,
                       isLoading: viewModel.gallerySize.isEmpty
                      ),
            MediaTitle(imageName: "person.2.fill",
                       title: "Contact",
                       size: viewModel.contactsCount,
                       isLoading: viewModel.contactsCount.isEmpty
                      ),
            MediaTitle(imageName: "calendar",
                       title: "Calendar",
                       size: viewModel.eventsCount,
                       isLoading: viewModel.eventsCount.isEmpty
                      )
        ]
    }
    
    init() { }
    
    var body: some View {
        NavigationView {
            VStack {
                // MARK: - Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.phoneModel)
                            .font(.title2).bold()
                            .foregroundColor(.white)
                        Text(viewModel.systemVersion)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    Spacer()
                    Button(action: {}) {
                        Text("★ PRO")
                            .font(.subheadline).bold()
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.orange)
                            .cornerRadius(6)
                    }
                    Button(action: {}) {
                        Image(systemName: "gearshape.fill")
                            .font(.title3)
                            .foregroundColor(.white)
                            .padding(6)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }
                }
                .padding()
                
                // MARK: - Circular Progress
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 12)
                    Circle()
                        .trim(from: 0, to: viewModel.usedPercent/100)
                        .stroke(Color.white, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    
                    VStack {
                        Text("\(Int(viewModel.usedPercent))%")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white)
                        Text(String(format: "%.1f / %.0f GB", viewModel.usedSpace, viewModel.totalSpace))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .frame(width: 200, height: 200)
                .padding(.bottom, 30)
                
                // MARK: - Button SMART ANALYZE
                Button(action: {}) {
                    Text("SMART ANALYZE")
                        .font(.headline).bold()
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(24)
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                
                // MARK: - List for categories
                
                List {
                    ForEach(items, id: \.title) { item in
                        NavigationLink(destination: destinationView(for: item.title)) {
                            HStack {
                                Image(systemName: item.imageName)
                                    .foregroundColor(item.size == "Need access" ? .secondary : .blue)
                                    .frame(width: 24, height: 24)
                                
                                Text(item.title)
                                    .font(.body)
                                
                                Spacer()
                                
                                if item.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                        .scaleEffect(0.7)
                                } else {
                                    Text(item.size)
                                        .font(.caption)
                                        .foregroundColor(item.size == "Need access" ? .blue : .secondary)
                                }
                            }
                            .padding(.vertical, 12)
                        }
                        .listRowBackground(Color.clear)
                    }
                }
                .onAppear {
                    viewModel.calculateGallerySize()
                    viewModel.calculateContactsSize()
                    viewModel.calculateEventsSize()
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                LinearGradient(colors: [Color.blue, Color.blue.opacity(0.6), Color.white.opacity(0.2), Color.white],
                               startPoint: .top,
                               endPoint: .bottom)
                .ignoresSafeArea()
            )
        }
    }
    
    @ViewBuilder
    func destinationView(for itemName: String) -> some View {
        switch itemName {
        case "Photos & Videos":
            PhotosAndVideosView()
        default:
            Text("Unknown item")
        }
    }
}
