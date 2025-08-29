//
//  ContactsManager.swift
//  MSCleaner
//
//  Created by Anita Stashevskaya on 28.08.2025.
//

import Contacts

final class ContactsManager {
    func checkContactsPermission() -> Bool {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        switch status {
        case .authorized:
            return true
        case .notDetermined, .restricted, .denied:
            return false
        default:
            return false
        }
    }
    
    func contactsCount() async -> Int {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let store = CNContactStore()
                let keys: [CNKeyDescriptor] = [CNContactIdentifierKey as CNKeyDescriptor]
                let request = CNContactFetchRequest(keysToFetch: keys)
                var count = 0
                do {
                    try store.enumerateContacts(with: request) { _, _ in
                        count += 1
                    }
                    continuation.resume(returning: count)
                } catch {
                    continuation.resume(returning: 0)
                }
            }
        }
    }
}
