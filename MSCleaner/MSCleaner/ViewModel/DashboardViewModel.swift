//
//  DashboardViewModel.swift
//  MSCleaner
//
//  Created by Anita Stashevskaya on 28.08.2025.
//

import SwiftUI

final class DashboardViewModel: ObservableObject {
    private let galeryManager = GalleryManager()
    private let contactsManager = ContactsManager()
    private let eventsManager = CalendarEventsManager()
    lazy var phoneModel: String = {
        deviceModelName()
    }()
    let systemVersion = "iOS \(UIDevice.current.systemVersion)"
    var usedSpace: Double = 0
    var totalSpace: Double = 0
    var usedPercent: Double = 0
    
    @Published var gallerySize: String = ""
    @Published var contactsCount: String = ""
    @Published var eventsCount: String = ""
    
    init() {
        storageUsagePercent()
    }
    
    func calculateGallerySize() {
        guard galeryManager.hasAccessToGallery() else {
            self.gallerySize = "Need access" // move permission request here
            return
        }
        Task {
            let size = await galeryManager.calculateGallerySize()
            await MainActor.run {
                self.gallerySize = String(format: "%.2f GB", size)
            }
        }
    }
    
    func calculateContactsSize() {
        guard contactsManager.hasAccessToContacts() else {
            contactsCount = "Need access"
            return
        }
        Task {
            let contacts = await contactsManager.contactsCount()
            await MainActor.run {
                contactsCount = "\(contacts)"
            }
        }
    }
    
    func calculateEventsSize() {
        guard eventsManager.hasAccessToCalendar() else {
            eventsCount = "Need access"
            return
        }
        eventsCount = "\(eventsManager.getEventsCount())"
    }
    
    // MARK: - Storage usage
    
    func storageUsagePercent() {
        let attributes = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
        guard let attributes, let total = attributes[.systemSize] as? NSNumber,
              let free = attributes[.systemFreeSize] as? NSNumber else { return }
        let totalS = total.doubleValue
        let freeSpace = free.doubleValue
        let usedS = totalS - freeSpace
        usedPercent = (usedS / totalS) * 100.0
        totalSpace = (totalS  * pow(10.0, -9.0)).rounded(.up)
        usedSpace = (usedS  * pow(10.0, -9.0))
    }
    
    private func deviceModelName() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machine = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
        
        return mapToDevice(identifier: machine)
    }
    
    private func mapToDevice(identifier: String) -> String {
        switch identifier {
            // iPhone 8 / 8 Plus / X
        case "iPhone10,1", "iPhone10,4": return "iPhone 8"
        case "iPhone10,2", "iPhone10,5": return "iPhone 8 Plus"
        case "iPhone10,3", "iPhone10,6": return "iPhone X"
            
            // iPhone XR / XS / XS Max
        case "iPhone11,2": return "iPhone XS"
        case "iPhone11,4", "iPhone11,6": return "iPhone XS Max"
        case "iPhone11,8": return "iPhone XR"
            
            // iPhone 11 / 11 Pro / 11 Pro Max
        case "iPhone12,1": return "iPhone 11"
        case "iPhone12,3": return "iPhone 11 Pro"
        case "iPhone12,5": return "iPhone 11 Pro Max"
            
            // iPhone SE (2nd gen)
        case "iPhone12,8": return "iPhone SE (2nd gen)"
            
            // iPhone 12 lineup
        case "iPhone13,1": return "iPhone 12 mini"
        case "iPhone13,2": return "iPhone 12"
        case "iPhone13,3": return "iPhone 12 Pro"
        case "iPhone13,4": return "iPhone 12 Pro Max"
            
            // iPhone 13 lineup
        case "iPhone14,4": return "iPhone 13 mini"
        case "iPhone14,5": return "iPhone 13"
        case "iPhone14,2": return "iPhone 13 Pro"
        case "iPhone14,3": return "iPhone 13 Pro Max"
            
            // iPhone SE (3rd gen)
        case "iPhone14,6": return "iPhone SE (3rd gen)"
            
            // iPhone 14 lineup
        case "iPhone14,7": return "iPhone 14"
        case "iPhone14,8": return "iPhone 14 Plus"
        case "iPhone15,2": return "iPhone 14 Pro"
        case "iPhone15,3": return "iPhone 14 Pro Max"
            
            // iPhone 15 lineup
        case "iPhone15,4": return "iPhone 15"
        case "iPhone15,5": return "iPhone 15 Plus"
        case "iPhone16,1": return "iPhone 15 Pro"
        case "iPhone16,2": return "iPhone 15 Pro Max"
            
            // iPhone 16 lineup
        case "iPhone17,3": return "iPhone 16"
        case "iPhone17,4": return "iPhone 16 Plus"
        case "iPhone17,1": return "iPhone 16 Pro"
        case "iPhone17,2": return "iPhone 16 Pro Max"
        case "iPhone17,5": return "iPhone 16e"
            
            // Simulator
        case "i386", "x86_64", "arm64": return "Simulator"
            
        default: return identifier
        }
    }
}

extension Double {
    var roundedTo2: Double {
        (self * 100).rounded() / 100
    }
}
