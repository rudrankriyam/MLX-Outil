import Foundation
import EventKit
import os

/// Error types for calendar operations
public enum CalendarError: Error, LocalizedError {
    case accessDenied
    case invalidAction
    case missingTitle
    case invalidStartDate
    case invalidEndDate
    case missingEventId
    case eventNotFound
    
    public var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Access to calendar denied. Please grant permission in Settings."
        case .invalidAction:
            return "Invalid action. Use 'create', 'query', 'read', or 'update'."
        case .missingTitle:
            return "Title is required to create an event."
        case .invalidStartDate:
            return "Invalid start date format. Use YYYY-MM-DD HH:mm:ss"
        case .invalidEndDate:
            return "Invalid end date format. Use YYYY-MM-DD HH:mm:ss"
        case .missingEventId:
            return "Event ID is required."
        case .eventNotFound:
            return "Event not found with the provided ID."
        }
    }
}

/// Input for calendar operations
public struct CalendarInput: Codable, Sendable {
    public let action: String
    public let title: String?
    public let startDate: String?
    public let endDate: String?
    public let location: String?
    public let notes: String?
    public let calendarName: String?
    public let daysAhead: Int?
    public let eventId: String?
    
    public init(
        action: String,
        title: String? = nil,
        startDate: String? = nil,
        endDate: String? = nil,
        location: String? = nil,
        notes: String? = nil,
        calendarName: String? = nil,
        daysAhead: Int? = nil,
        eventId: String? = nil
    ) {
        self.action = action
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.location = location
        self.notes = notes
        self.calendarName = calendarName
        self.daysAhead = daysAhead
        self.eventId = eventId
    }
}

/// Output for calendar operations
public struct CalendarOutput: Codable, Sendable {
    public let status: String
    public let message: String
    public let eventId: String?
    public let events: String?
    public let count: Int?
    
    public init(status: String, message: String, eventId: String? = nil, events: String? = nil, count: Int? = nil) {
        self.status = status
        self.message = message
        self.eventId = eventId
        self.events = events
        self.count = count
    }
}

/// Manager for calendar operations using EventKit
@MainActor
public class CalendarManager {
    public static let shared = CalendarManager()
    
    private let eventStore = EKEventStore()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "MLXTools", category: "CalendarManager")
    
    private init() {
        logger.info("CalendarManager initialized")
    }
    
    /// Main entry point for calendar operations
    public func performAction(_ input: CalendarInput) async throws -> CalendarOutput {
        logger.info("Performing calendar action: \(input.action)")
        
        // Request access if needed
        let authorized = await requestAccess()
        guard authorized else {
            throw CalendarError.accessDenied
        }
        
        switch input.action.lowercased() {
        case "create":
            return try createEvent(input: input)
        case "query":
            return try queryEvents(input: input)
        case "read":
            return try readEvent(eventId: input.eventId)
        case "update":
            return try updateEvent(input: input)
        default:
            throw CalendarError.invalidAction
        }
    }
    
    private nonisolated func requestAccess() async -> Bool {
        let store = EKEventStore()
        do {
            if #available(macOS 14.0, iOS 17.0, *) {
                return try await store.requestFullAccessToEvents()
            } else {
                return try await store.requestAccess(to: .event)
            }
        } catch {
            return false
        }
    }
    
    private func createEvent(input: CalendarInput) throws -> CalendarOutput {
        guard let title = input.title, !title.isEmpty else {
            throw CalendarError.missingTitle
        }
        
        guard let startDateString = input.startDate,
              let startDate = parseDate(startDateString) else {
            throw CalendarError.invalidStartDate
        }
        
        let endDate: Date
        if let endDateString = input.endDate {
            guard let parsedEndDate = parseDate(endDateString) else {
                throw CalendarError.invalidEndDate
            }
            endDate = parsedEndDate
        } else {
            // Default to 1 hour duration
            endDate = startDate.addingTimeInterval(3600)
        }
        
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        
        if let location = input.location {
            event.location = location
        }
        
        if let notes = input.notes {
            event.notes = notes
        }
        
        // Set calendar
        if let calendarName = input.calendarName {
            let calendars = eventStore.calendars(for: .event)
            if let calendar = calendars.first(where: { $0.title == calendarName }) {
                event.calendar = calendar
            } else {
                event.calendar = eventStore.defaultCalendarForNewEvents
            }
        } else {
            event.calendar = eventStore.defaultCalendarForNewEvents
        }
        
        do {
            try eventStore.save(event, span: .thisEvent)
            
            logger.info("Event created successfully: \(event.eventIdentifier ?? "")")
            
            return CalendarOutput(
                status: "success",
                message: "Event created successfully",
                eventId: event.eventIdentifier
            )
        } catch {
            logger.error("Failed to create event: \(error)")
            throw error
        }
    }
    
    private func queryEvents(input: CalendarInput) throws -> CalendarOutput {
        let startDate = Date()
        let daysToQuery = input.daysAhead ?? 7
        let endDate = Calendar.current.date(byAdding: .day, value: daysToQuery, to: startDate)!
        
        let calendars = eventStore.calendars(for: .event)
        
        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: calendars
        )
        
        let events = eventStore.events(matching: predicate)
        
        var eventsDescription = ""
        
        for (index, event) in events.enumerated() {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .short
            
            let location = event.location != nil ? " at \(event.location!)" : ""
            let calendar = event.calendar?.title ?? "Unknown Calendar"
            
            eventsDescription += "\(index + 1). \(event.title ?? "Untitled")\n"
            eventsDescription += "   When: \(dateFormatter.string(from: event.startDate)) - \(dateFormatter.string(from: event.endDate))\n"
            eventsDescription += "   Calendar: \(calendar)\(location)\n"
            if let notes = event.notes, !notes.isEmpty {
                eventsDescription += "   Notes: \(notes.prefix(50))...\n"
            }
            eventsDescription += "\n"
        }
        
        if eventsDescription.isEmpty {
            eventsDescription = "No events found in the next \(daysToQuery) days"
        }
        
        return CalendarOutput(
            status: "success",
            message: "Found \(events.count) event(s) in the next \(daysToQuery) days",
            events: eventsDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            count: events.count
        )
    }
    
    private func readEvent(eventId: String?) throws -> CalendarOutput {
        guard let id = eventId else {
            throw CalendarError.missingEventId
        }
        
        guard let event = eventStore.event(withIdentifier: id) else {
            throw CalendarError.eventNotFound
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .short
        
        let eventDetails = """
        Title: \(event.title ?? "")
        Date: \(dateFormatter.string(from: event.startDate)) - \(dateFormatter.string(from: event.endDate))
        Location: \(event.location ?? "")
        Notes: \(event.notes ?? "")
        Calendar: \(event.calendar?.title ?? "")
        """
        
        return CalendarOutput(
            status: "success",
            message: "Event details retrieved",
            eventId: event.eventIdentifier,
            events: eventDetails
        )
    }
    
    private func updateEvent(input: CalendarInput) throws -> CalendarOutput {
        guard let eventId = input.eventId else {
            throw CalendarError.missingEventId
        }
        
        guard let event = eventStore.event(withIdentifier: eventId) else {
            throw CalendarError.eventNotFound
        }
        
        // Update fields if provided
        if let title = input.title {
            event.title = title
        }
        
        if let startDateString = input.startDate,
           let startDate = parseDate(startDateString) {
            event.startDate = startDate
        }
        
        if let endDateString = input.endDate,
           let endDate = parseDate(endDateString) {
            event.endDate = endDate
        }
        
        if let location = input.location {
            event.location = location
        }
        
        if let notes = input.notes {
            event.notes = notes
        }
        
        do {
            try eventStore.save(event, span: .thisEvent)
            
            return CalendarOutput(
                status: "success",
                message: "Event updated successfully",
                eventId: event.eventIdentifier
            )
        } catch {
            logger.error("Failed to update event: \(error)")
            throw error
        }
    }
    
    private func parseDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone.current
        return formatter.date(from: dateString)
    }
}