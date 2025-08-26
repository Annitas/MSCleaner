//
//  DashboardView.swift
//  MSCleaner
//
//  Created by Anita Stashevskaya on 26.08.2025.
//

import SwiftUI

struct DashboardView: View {
    let phoneModel = "iPhone 14 Pro"
    let iosVersion = "iOS 18.0"
    let used: Double = 32.2
    let total: Double = 128
    let percent: Double = 0.38
    
    var body: some View {
        VStack {
            // MARK: - Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(phoneModel)
                        .font(.title2).bold()
                        .foregroundColor(.white)
                    Text(iosVersion)
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
            
            Spacer()
            
            // MARK: - Circular Progress
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 12)
                Circle()
                    .trim(from: 0, to: percent)
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                
                VStack {
                    Text("\(Int(percent * 100))%")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)
                    Text(String(format: "%.1f / %.0f GB", used, total))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .frame(width: 200, height: 200)
            .padding(.bottom, 30)
            
            // MARK: - Button
            Button(action: {}) {
                Text("SMART ANALYZE")
                    .font(.headline).bold()
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            
            // MARK: - List
            NavigationView {
                VStack(spacing: 0) {
                    StorageRow(icon: "photo.on.rectangle", title: "Photos & Videos", detail: "2.2 GB")
                    Divider()
                    StorageRow(icon: "person.2.fill", title: "Contact", detail: "251")
                    Divider()
                    StorageRow(icon: "calendar", title: "Calendar", detail: "4214")
                }
                .padding(.top, 20)
                .background(Color.white)
                .cornerRadius(12)
                .padding()
            }
        }
        .background(
            LinearGradient(colors: [Color.blue, Color.blue.opacity(0.8)],
                           startPoint: .top,
                           endPoint: .bottom)
            .ignoresSafeArea()
        )
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

struct StorageRow: View {
    let icon: String
    let title: String
    let detail: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24, height: 24)
            Text(title)
                .foregroundColor(.black)
            Spacer()
            Text(detail)
                .foregroundColor(.gray)
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
}
