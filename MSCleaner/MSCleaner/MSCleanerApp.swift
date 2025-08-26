//
//  MSCleanerApp.swift
//  MSCleaner
//
//  Created by Anita Stashevskaya on 05.08.2025.
//

import SwiftUI

@main
struct MSCleanerApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            DashboardView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
