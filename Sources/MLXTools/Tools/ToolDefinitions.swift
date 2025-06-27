import Foundation
import MLXLMCommon
import HealthKit

// MARK: - Tool Input/Output Types

public struct WeatherInput: Codable, Sendable {
    public let location: String
    
    public init(location: String) {
        self.location = location
    }
}

public struct EmptyInput: Codable, Sendable {
    public init() {}
}

public struct WorkoutOutput: Codable, Sendable {
    public let summary: String
    
    public init(summary: String) {
        self.summary = summary
    }
}

public struct SearchInput: Codable, Sendable {
    public let query: String
    
    public init(query: String) {
        self.query = query
    }
}

public struct SearchOutput: Codable, Sendable {
    public let results: String
    
    public init(results: String) {
        self.results = results
    }
}

// MARK: - Tool Definitions

public let weatherTool = Tool<WeatherInput, WeatherData>(
    name: "get_weather_data",
    description: "Get current weather data for a specific location",
    parameters: [
        .required("location", type: .string, description: "The city and state, e.g. New Delhi, Delhi")
    ]
) { @MainActor input in
    let weatherService = WeatherKitManager.shared
    let response = try await weatherService.fetchWeather(forCity: input.location)
    return response
}

public let workoutTool = Tool<EmptyInput, WorkoutOutput>(
    name: "get_workout_summary",
    description: "Get a summary of workouts for this week",
    parameters: []
) { @MainActor _ in
    let workouts = try await HealthKitManager.shared.fetchWorkouts(for: .week(Date()))
    if workouts.isEmpty {
        return WorkoutOutput(summary: "No workouts found for this week.")
    }
    let summary = OutputFormatter.formatWeeklyWorkoutSummary(workouts, using: HealthKitManager.shared)
    return WorkoutOutput(summary: summary)
}

public let searchTool = Tool<SearchInput, SearchOutput>(
    name: "search_duckduckgo",
    description: "Search DuckDuckGo for information on a topic",
    parameters: [
        .required("query", type: .string, description: "The search query to look up")
    ]
) { @MainActor input in
    let results = try await DuckDuckGoManager.shared.search(query: input.query)
    return SearchOutput(results: results)
}

public let calendarTool = Tool<CalendarInput, CalendarOutput>(
    name: "manage_calendar",
    description: "Create, read, update, and query calendar events",
    parameters: [
        .required("action", type: .string, description: "The action to perform: 'create', 'query', 'read', or 'update'"),
        .optional("title", type: .string, description: "Event title"),
        .optional("startDate", type: .string, description: "Start date in format YYYY-MM-DD HH:mm:ss"),
        .optional("endDate", type: .string, description: "End date in format YYYY-MM-DD HH:mm:ss"),
        .optional("location", type: .string, description: "Event location"),
        .optional("notes", type: .string, description: "Event notes"),
        .optional("calendarName", type: .string, description: "Calendar name (defaults to default calendar)"),
        .optional("daysAhead", type: .int, description: "Number of days to query (for query action)"),
        .optional("eventId", type: .string, description: "Event identifier (for read/update actions)")
    ]
) { @MainActor input in
    let calendarManager = CalendarManager.shared
    let response = try await calendarManager.performAction(input)
    return response
}

public let remindersTool = Tool<RemindersInput, RemindersOutput>(
    name: "manage_reminders",
    description: "Create, read, update, complete, and query reminders",
    parameters: [
        .required("action", type: .string, description: "The action to perform: 'create', 'query', 'complete', 'update', or 'delete'"),
        .optional("title", type: .string, description: "Reminder title"),
        .optional("notes", type: .string, description: "Reminder notes"),
        .optional("dueDate", type: .string, description: "Due date in format YYYY-MM-DD HH:mm:ss"),
        .optional("priority", type: .string, description: "Priority level: 'none', 'low', 'medium', 'high'"),
        .optional("listName", type: .string, description: "List name (defaults to default list)"),
        .optional("reminderId", type: .string, description: "Reminder identifier (for complete/update/delete actions)"),
        .optional("filter", type: .string, description: "Filter for querying: 'all', 'incomplete', 'completed', 'today', 'overdue'")
    ]
) { @MainActor input in
    let remindersManager = RemindersManager.shared
    let response = try await remindersManager.performAction(input)
    return response
}

public let contactsTool = Tool<ContactsInput, ContactsOutput>(
    name: "manage_contacts",
    description: "Search, read, and create contacts",
    parameters: [
        .required("action", type: .string, description: "The action to perform: 'search', 'read', or 'create'"),
        .optional("query", type: .string, description: "Search query for finding contacts"),
        .optional("contactId", type: .string, description: "Contact identifier (for read action)"),
        .optional("givenName", type: .string, description: "Given name (for create action)"),
        .optional("familyName", type: .string, description: "Family name (for create action)"),
        .optional("email", type: .string, description: "Email address (for create action)"),
        .optional("phoneNumber", type: .string, description: "Phone number (for create action)"),
        .optional("organization", type: .string, description: "Organization name (for create action)")
    ]
) { @MainActor input in
    let contactsManager = ContactsManager.shared
    let response = try await contactsManager.performAction(input)
    return response
}

public let locationTool = Tool<LocationInput, LocationOutput>(
    name: "access_location",
    description: "Get current location, geocode addresses, and calculate distances",
    parameters: [
        .required("action", type: .string, description: "The action to perform: 'current', 'geocode', 'reverse', or 'distance'"),
        .optional("address", type: .string, description: "Address to geocode (for geocode action)"),
        .optional("latitude", type: .double, description: "Latitude coordinate"),
        .optional("longitude", type: .double, description: "Longitude coordinate"),
        .optional("latitude2", type: .double, description: "Second latitude (for distance calculation)"),
        .optional("longitude2", type: .double, description: "Second longitude (for distance calculation)")
    ]
) { @MainActor input in
    let locationManager = LocationManager.shared
    let response = try await locationManager.performAction(input)
    return response
}

public let musicTool = Tool<MusicInput, MusicOutput>(
    name: "access_music",
    description: "Search and play music, manage playback",
    parameters: [
        .required("action", type: .string, description: "The action to perform: 'search', 'play', 'pause', 'next', 'previous', or 'currentSong'"),
        .optional("query", type: .string, description: "Search query for songs, artists, or albums"),
        .optional("searchType", type: .string, description: "Type of search: 'song', 'artist', 'album'"),
        .optional("limit", type: .int, description: "Maximum number of results (defaults to 10)"),
        .optional("itemId", type: .string, description: "Song or album ID to play")
    ]
) { @MainActor input in
    let musicManager = MusicManager.shared
    let response = try await musicManager.performAction(input)
    return response
}