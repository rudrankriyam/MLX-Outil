import Foundation
import MLXLMCommon
import HealthKit
import Tokenizers

@MainActor
class ToolManager {
    static let shared = ToolManager()
    
    private let healthManager = HealthKitManager.shared
    private let weatherManager = WeatherKitManager.shared
    private let searchManager = DuckDuckGoManager.shared
    private let loadingManager = LoadingManager.shared
    
    private init() {}
    
    // MARK: - Tool Definitions
    
    // Weather Tool
    struct WeatherInput: Codable, Sendable {
        let location: String
    }
    
    let weatherTool = Tool<WeatherInput, WeatherData>(
        name: "get_weather_data",
        description: "Get current weather data for a specific location",
        parameters: [
            .required("location", type: .string, description: "The city and state, e.g. New Delhi, Delhi")
        ]
    ) { input in
        let weatherService = WeatherKitManager.shared
        let response = try await weatherService.fetchWeather(forCity: input.location)
        return response
    }
    
    // Workout Tool
    struct WorkoutInput: Codable, Sendable {
        // No parameters needed for weekly summary
    }
    
    struct WorkoutOutput: Codable, Sendable {
        let summary: String
    }
    
    lazy var workoutTool = Tool<WorkoutInput, WorkoutOutput>(
        name: "get_workout_summary",
        description: "Get a summary of workouts for this week",
        parameters: []
    ) { _ in
        let workouts = try await HealthKitManager.shared.fetchWorkouts(for: .week(Date()))
        if workouts.isEmpty {
            return WorkoutOutput(summary: "No workouts found for this week.")
        }
        let summary = OutputFormatter.formatWeeklyWorkoutSummary(workouts, using: HealthKitManager.shared)
        return WorkoutOutput(summary: summary)
    }
    
    // Search Tool
    struct SearchInput: Codable, Sendable {
        let query: String
    }
    
    struct SearchOutput: Codable, Sendable {
        let results: String
    }
    
    let searchTool = Tool<SearchInput, SearchOutput>(
        name: "search_duckduckgo",
        description: "Search DuckDuckGo for information on a topic",
        parameters: [
            .required("query", type: .string, description: "The search query to look up")
        ]
    ) { input in
        LoadingManager.shared.startLoading(message: "Searching DuckDuckGo for \(input.query)...")
        defer { LoadingManager.shared.stopLoading() }
        
        let results = try await DuckDuckGoManager.shared.search(query: input.query)
        return SearchOutput(results: results)
    }
    
    // MARK: - Tool Registry
    
    var allTools: [any ToolProtocol] {
        [weatherTool, workoutTool, searchTool]
    }
    
    var toolSchemas: [ToolSpec] {
        allTools.map { $0.schema }
    }
    
    // MARK: - Tool Execution
    
    func execute(toolCall: ToolCall) async throws -> String {
        do {
            switch toolCall.function.name {
            case "get_weather_data":
                let result = try await toolCall.execute(with: weatherTool)
                return OutputFormatter.formatWeatherData(result)
                
            case "get_workout_summary":
                let result = try await toolCall.execute(with: workoutTool)
                return result.summary
                
            case "search_duckduckgo":
                let result = try await toolCall.execute(with: searchTool)
                return result.results
                
            default:
                throw ToolManagerError.unknownTool(name: toolCall.function.name)
            }
        } catch let error as ToolError {
            throw ToolManagerError.toolExecutionFailed(toolName: toolCall.function.name, error: error)
        } catch {
            throw ToolManagerError.toolExecutionFailed(toolName: toolCall.function.name, error: error)
        }
    }
}

// MARK: - Errors

enum ToolManagerError: Error, LocalizedError {
    case unknownTool(name: String)
    case toolExecutionFailed(toolName: String, error: Error)
    
    var errorDescription: String? {
        switch self {
        case .unknownTool(let name):
            return "Unknown tool: \(name)"
        case .toolExecutionFailed(let toolName, let error):
            return "Tool '\(toolName)' execution failed: \(error.localizedDescription)"
        }
    }
}
