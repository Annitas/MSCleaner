//
//  AllowAccessView.swift
//  MSCleaner
//
//  Created by Anita Stashevskaya on 30.08.2025.
//

import SwiftUI

struct AllowAccessView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("Allow")
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            Text("to access “All Contacts”")
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text("To provide you with a better service and work more effectively, App needs to access \n“All Contacts”.")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            
            Image("allowPhotoAccess")
                .padding(.top, 24)
                .padding(.bottom, 40)
            
            Button(action: {
                print("Enable tapped")
            }) {
                Text("Enable Now")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
        }
        .padding(.top, 24)
    }
}

#Preview {
    AllowAccessView()
}
