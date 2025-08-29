//
//  CalendarEventsManager.swift
//  MSCleaner
//
//  Created by Anita Stashevskaya on 29.08.2025.
//

import EventKit

final class CalendarEventsManager {
    private let eventStore = EKEventStore()
    
    func hasAccessToCalendar() -> Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        return status == .authorized
    }
    
    func requestAccess(completion: @escaping (Bool) -> Void) {
        eventStore.requestAccess(to: .event) { granted, error in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }
    
    func getEventsCount(startDate: Date? = nil, endDate: Date? = nil) -> Int {
        let start = startDate ?? Calendar.current.date(byAdding: .year, value: -1, to: Date())!
        let end = endDate ?? Calendar.current.date(byAdding: .year, value: 1, to: Date())!
        let predicate = eventStore.predicateForEvents(withStart: start,
                                                      end: end,
                                                      calendars: nil)
        let events = eventStore.events(matching: predicate)
        return events.count
    }
}

