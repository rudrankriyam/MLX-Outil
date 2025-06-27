import Foundation
import EventKit
import os

/// Error types for reminders operations
public enum RemindersError: Error, LocalizedError {
    case accessDenied
    case invalidAction
    case missingTitle
    case missingReminderId
    case reminderNotFound
    
    public var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Access to reminders denied. Please grant permission in Settings."
        case .invalidAction:
            return "Invalid action. Use 'create', 'query', 'complete', 'update', or 'delete'."
        case .missingTitle:
            return "Title is required to create a reminder."
        case .missingReminderId:
            return "Reminder ID is required."
        case .reminderNotFound:
            return "Reminder not found with the provided ID."
        }
    }
}

/// Input for reminders operations
public struct RemindersInput: Codable, Sendable {
    public let action: String
    public let title: String?
    public let notes: String?
    public let dueDate: String?
    public let priority: String?
    public let listName: String?
    public let reminderId: String?
    public let filter: String?
    
    public init(
        action: String,
        title: String? = nil,
        notes: String? = nil,
        dueDate: String? = nil,
        priority: String? = nil,
        listName: String? = nil,
        reminderId: String? = nil,
        filter: String? = nil
    ) {
        self.action = action
        self.title = title
        self.notes = notes
        self.dueDate = dueDate
        self.priority = priority
        self.listName = listName
        self.reminderId = reminderId
        self.filter = filter
    }
}

/// Output for reminders operations
public struct RemindersOutput: Codable, Sendable {
    public let status: String
    public let message: String
    public let reminderId: String?
    public let reminders: String?
    public let count: Int?
    
    public init(status: String, message: String, reminderId: String? = nil, reminders: String? = nil, count: Int? = nil) {
        self.status = status
        self.message = message
        self.reminderId = reminderId
        self.reminders = reminders
        self.count = count
    }
}

/// Manager for reminders operations using EventKit
@MainActor
public class RemindersManager {
    public static let shared = RemindersManager()
    
    private let eventStore = EKEventStore()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "MLXTools", category: "RemindersManager")
    
    private init() {
        logger.info("RemindersManager initialized")
    }
    
    /// Main entry point for reminders operations
    public func performAction(_ input: RemindersInput) async throws -> RemindersOutput {
        logger.info("Performing reminders action: \(input.action)")
        
        // Request access if needed
        let authorized = await requestAccess()
        guard authorized else {
            throw RemindersError.accessDenied
        }
        
        switch input.action.lowercased() {
        case "create":
            return try createReminder(input: input)
        case "query":
            return try await queryReminders(input: input)
        case "complete":
            return try completeReminder(reminderId: input.reminderId)
        case "update":
            return try updateReminder(input: input)
        case "delete":
            return try deleteReminder(reminderId: input.reminderId)
        default:
            throw RemindersError.invalidAction
        }
    }
    
    private nonisolated func requestAccess() async -> Bool {
        let store = EKEventStore()
        do {
            if #available(macOS 14.0, iOS 17.0, *) {
                return try await store.requestFullAccessToReminders()
            } else {
                return try await store.requestAccess(to: .reminder)
            }
        } catch {
            return false
        }
    }
    
    private func createReminder(input: RemindersInput) throws -> RemindersOutput {
        guard let title = input.title, !title.isEmpty else {
            throw RemindersError.missingTitle
        }
        
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = title
        
        if let notes = input.notes {
            reminder.notes = notes
        }
        
        if let dueDateString = input.dueDate,
           let dueDate = parseDate(dueDateString) {
            reminder.dueDateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: dueDate
            )
        }
        
        // Set priority
        if let priorityString = input.priority {
            switch priorityString.lowercased() {
            case "high":
                reminder.priority = 1
            case "medium":
                reminder.priority = 5
            case "low":
                reminder.priority = 9
            default:
                reminder.priority = 0 // none
            }
        }
        
        // Set calendar (list)
        if let listName = input.listName {
            let calendars = eventStore.calendars(for: .reminder)
            if let calendar = calendars.first(where: { $0.title == listName }) {
                reminder.calendar = calendar
            } else {
                reminder.calendar = eventStore.defaultCalendarForNewReminders()
            }
        } else {
            reminder.calendar = eventStore.defaultCalendarForNewReminders()
        }
        
        do {
            try eventStore.save(reminder, commit: true)
            
            logger.info("Reminder created successfully: \(reminder.calendarItemIdentifier)")
            
            return RemindersOutput(
                status: "success",
                message: "Reminder created successfully",
                reminderId: reminder.calendarItemIdentifier
            )
        } catch {
            logger.error("Failed to create reminder: \(error)")
            throw error
        }
    }
    
    private func queryReminders(input: RemindersInput) async throws -> RemindersOutput {
        let calendars = eventStore.calendars(for: .reminder)
        var predicate: NSPredicate
        
        let filter = input.filter?.lowercased() ?? "incomplete"
        
        switch filter {
        case "all":
            predicate = eventStore.predicateForReminders(in: calendars)
        case "completed":
            predicate = eventStore.predicateForCompletedReminders(withCompletionDateStarting: nil, ending: nil, calendars: calendars)
        case "today":
            let startOfDay = Calendar.current.startOfDay(for: Date())
            let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
            predicate = eventStore.predicateForIncompleteReminders(withDueDateStarting: startOfDay, ending: endOfDay, calendars: calendars)
        case "overdue":
            predicate = eventStore.predicateForIncompleteReminders(withDueDateStarting: nil, ending: Date(), calendars: calendars)
        default: // "incomplete"
            predicate = eventStore.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: calendars)
        }
        
        let fetchedReminders: [EKReminder] = await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { fetchedReminders in
                continuation.resume(returning: fetchedReminders ?? [])
            }
        }
        
        // Sort reminders
        let reminders = fetchedReminders.sorted { reminder1, reminder2 in
            // First by completion status
            if reminder1.isCompleted != reminder2.isCompleted {
                return !reminder1.isCompleted
            }
            
            // Then by due date
            if let date1 = reminder1.dueDateComponents?.date,
               let date2 = reminder2.dueDateComponents?.date {
                return date1 < date2
            }
            
            // Reminders with due dates come before those without
            if reminder1.dueDateComponents != nil && reminder2.dueDateComponents == nil {
                return true
            }
            
            return false
        }
        
        var remindersDescription = ""
        
        for (index, reminder) in reminders.enumerated() {
            let completed = reminder.isCompleted ? "✓" : "○"
            let priority = getPriorityString(reminder.priority)
            let dueDate = formatDateComponents(reminder.dueDateComponents)
            let list = reminder.calendar?.title ?? "Unknown List"
            
            remindersDescription += "\(index + 1). \(completed) \(reminder.title ?? "Untitled")\n"
            remindersDescription += "   List: \(list)\n"
            if !dueDate.isEmpty {
                remindersDescription += "   Due: \(dueDate)\n"
            }
            if priority != "None" {
                remindersDescription += "   Priority: \(priority)\n"
            }
            if let notes = reminder.notes, !notes.isEmpty {
                remindersDescription += "   Notes: \(notes.prefix(50))...\n"
            }
            remindersDescription += "\n"
        }
        
        if remindersDescription.isEmpty {
            remindersDescription = "No reminders found with filter '\(filter)'"
        }
        
        return RemindersOutput(
            status: "success",
            message: "Found \(reminders.count) reminder(s)",
            reminders: remindersDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            count: reminders.count
        )
    }
    
    private func completeReminder(reminderId: String?) throws -> RemindersOutput {
        guard let id = reminderId else {
            throw RemindersError.missingReminderId
        }
        
        guard let reminder = eventStore.calendarItem(withIdentifier: id) as? EKReminder else {
            throw RemindersError.reminderNotFound
        }
        
        reminder.isCompleted = true
        reminder.completionDate = Date()
        
        do {
            try eventStore.save(reminder, commit: true)
            
            return RemindersOutput(
                status: "success",
                message: "Reminder completed successfully",
                reminderId: reminder.calendarItemIdentifier
            )
        } catch {
            logger.error("Failed to complete reminder: \(error)")
            throw error
        }
    }
    
    private func updateReminder(input: RemindersInput) throws -> RemindersOutput {
        guard let reminderId = input.reminderId else {
            throw RemindersError.missingReminderId
        }
        
        guard let reminder = eventStore.calendarItem(withIdentifier: reminderId) as? EKReminder else {
            throw RemindersError.reminderNotFound
        }
        
        // Update fields if provided
        if let title = input.title {
            reminder.title = title
        }
        
        if let notes = input.notes {
            reminder.notes = notes
        }
        
        if let dueDateString = input.dueDate {
            if let dueDate = parseDate(dueDateString) {
                reminder.dueDateComponents = Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute],
                    from: dueDate
                )
            } else if dueDateString.lowercased() == "none" {
                reminder.dueDateComponents = nil
            }
        }
        
        if let priorityString = input.priority {
            switch priorityString.lowercased() {
            case "high":
                reminder.priority = 1
            case "medium":
                reminder.priority = 5
            case "low":
                reminder.priority = 9
            default:
                reminder.priority = 0
            }
        }
        
        do {
            try eventStore.save(reminder, commit: true)
            
            return RemindersOutput(
                status: "success",
                message: "Reminder updated successfully",
                reminderId: reminder.calendarItemIdentifier
            )
        } catch {
            logger.error("Failed to update reminder: \(error)")
            throw error
        }
    }
    
    private func deleteReminder(reminderId: String?) throws -> RemindersOutput {
        guard let id = reminderId else {
            throw RemindersError.missingReminderId
        }
        
        guard let reminder = eventStore.calendarItem(withIdentifier: id) as? EKReminder else {
            throw RemindersError.reminderNotFound
        }
        
        let title = reminder.title ?? "Untitled"
        
        do {
            try eventStore.remove(reminder, commit: true)
            
            return RemindersOutput(
                status: "success",
                message: "Reminder '\(title)' deleted successfully"
            )
        } catch {
            logger.error("Failed to delete reminder: \(error)")
            throw error
        }
    }
    
    private func parseDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone.current
        return formatter.date(from: dateString)
    }
    
    private func formatDateComponents(_ components: DateComponents?) -> String {
        guard let components = components,
              let date = Calendar.current.date(from: components) else {
            return ""
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func getPriorityString(_ priority: Int) -> String {
        switch priority {
        case 1...3:
            return "High"
        case 4...6:
            return "Medium"
        case 7...9:
            return "Low"
        default:
            return "None"
        }
    }
}