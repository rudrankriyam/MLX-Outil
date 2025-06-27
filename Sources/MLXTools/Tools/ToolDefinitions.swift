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