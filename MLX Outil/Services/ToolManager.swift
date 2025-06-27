import Foundation
import MLXLMCommon
import HealthKit
import Tokenizers
import os

@MainActor
class ToolManager {
    static let shared = ToolManager()
    
    private let healthManager = HealthKitManager.shared
    private let weatherManager = WeatherKitManager.shared
    private let searchManager = DuckDuckGoManager.shared
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "MLXOutil", category: "ToolManager")
    
    private init() {
        logger.info("ToolManager initialized")
        // Force initialization of tools
        _ = weatherTool
        _ = workoutTool
        _ = searchTool
        logger.info("All tools initialized")
    }
    
    // MARK: - Tool Definitions
    
    // Weather Tool
    struct WeatherInput: Codable, Sendable {
        let location: String
    }
    
    lazy var weatherTool = Tool<WeatherInput, WeatherData>(
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
    struct EmptyInput: Codable, Sendable {}
    
    struct WorkoutOutput: Codable, Sendable {
        let summary: String
    }
    
    lazy var workoutTool = Tool<EmptyInput, WorkoutOutput>(
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
    
    lazy var searchTool = Tool<SearchInput, SearchOutput>(
        name: "search_duckduckgo",
        description: "Search DuckDuckGo for information on a topic",
        parameters: [
            .required("query", type: .string, description: "The search query to look up")
        ]
    ) { input in
        let results = try await DuckDuckGoManager.shared.search(query: input.query)
        return SearchOutput(results: results)
    }
    
    // MARK: - Tool Registry
    
    var allTools: [any ToolProtocol] {
        let tools: [any ToolProtocol] = [weatherTool, workoutTool, searchTool]
        logger.info("ToolManager.allTools - Returning \(tools.count) tools:")
        for (index, tool) in tools.enumerated() {
            let schema = tool.schema
            if let function = schema["function"] as? [String: Any],
               let name = function["name"] as? String {
                logger.info("  Tool \(index): \(name)")
            }
        }
        return tools
    }
    
    var toolSchemas: [ToolSpec] {
        let schemas = allTools.map { $0.schema }
        logger.info("ToolManager.toolSchemas - Returning \(schemas.count) tool schemas:")
        for (index, schema) in schemas.enumerated() {
            if let function = schema["function"] as? [String: Any],
               let name = function["name"] as? String,
               let description = function["description"] as? String {
                logger.info("  Schema \(index): \(name) - \(description)")
            }
        }
        return schemas
    }
    
    // MARK: - Tool Execution
    
    func execute(toolCall: ToolCall) async throws -> String {
        logger.info("Executing tool call: \(toolCall.function.name)")
        logger.debug("Tool call arguments: \(toolCall.function.arguments)")
        
        do {
            switch toolCall.function.name {
            case "get_weather_data":
                logger.debug("Executing weather tool")
                let result = try await toolCall.execute(with: weatherTool)
                logger.info("Weather tool executed successfully")
                return try result.toolResult
                
            case "get_workout_summary":
                logger.debug("Executing workout tool")
                let result = try await toolCall.execute(with: workoutTool)
                logger.info("Workout tool executed successfully")
                return try result.toolResult
                
            case "search_duckduckgo":
                logger.debug("Executing search tool")
                let result = try await toolCall.execute(with: searchTool)
                logger.info("Search tool executed successfully")
                return try result.toolResult
                
            default:
                logger.error("Unknown tool: \(toolCall.function.name)")
                throw ToolManagerError.unknownTool(name: toolCall.function.name)
            }
        } catch let error as ToolError {
            logger.error("Tool error: \(error)")
            throw ToolManagerError.toolExecutionFailed(toolName: toolCall.function.name, error: error)
        } catch {
            logger.error("Unexpected error: \(error)")
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

// MARK: - Extensions

extension Encodable {
    var toolResult: String {
        get throws {
            let data = try JSONEncoder().encode(self)
            return String(data: data, encoding: .utf8) ?? "{}"
        }
    }
}
