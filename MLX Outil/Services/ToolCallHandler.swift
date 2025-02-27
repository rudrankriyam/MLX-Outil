import Foundation
import os 

enum ToolCallType: String, Codable {
    case getWorkoutSummary = "get_workout_summary"
    case getWeatherData = "get_weather_data"
    case searchDuckDuckGo = "search_duckduckgo"
}

struct ToolCall: Codable {
    let name: ToolCallType
    let arguments: ToolCallArguments
}

enum ToolCallArguments: Codable {
    case workout
    case weather(WeatherArguments)
    case search(SearchArguments)
    
    enum CodingKeys: String, CodingKey {
        case location
        case query
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        if let location = try? container.decode(String.self, forKey: .location) {
            self = .weather(WeatherArguments(location: location))
        } else if let query = try? container.decode(String.self, forKey: .query) {
            self = .search(SearchArguments(query: query))
        } else {
            self = .workout
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .workout:
            break
        case .weather(let args):
            try container.encode(args.location, forKey: .location)
        case .search(let args):
            try container.encode(args.query, forKey: .query)
        }
    }
}

struct WeatherArguments: Codable {
    let location: String
}

struct SearchArguments: Codable {
    let query: String
}

struct LlamaToolArguments: Codable {
    let parameters: [String: String]
}

struct LlamaToolCall: Codable {
    let name: ToolCallType
    let parameters: ToolCallArguments
}

class ToolCallHandler {
    private let healthManager: HealthKitManager
    private let weatherManager: WeatherKitManager
    private let searchManager = DuckDuckGoManager.shared
    private let loadingManager = LoadingManager.shared
    private var toolCallBuffer: String = ""
    private var isCollectingToolCall = false
    private let decoder = JSONDecoder()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ToolCallHandler")
    
    init(healthManager: HealthKitManager, weatherManager: WeatherKitManager) {
        self.healthManager = healthManager
        self.weatherManager = weatherManager
    }
    
    func processLLMOutput(_ text: String) async throws -> String {
        logger.debug("Processing LLM output: \(text)")
        
        if text.contains("<|python_tag|>") {
            logger.debug("Detected Llama format, handling accordingly")
            return try await handleLlamaFormat(text)
        }
        
        var tokenText = text
        if tokenText.hasPrefix("<tool_call>") {
            logger.debug("Found tool_call prefix, removing it")
            tokenText = tokenText.replacingOccurrences(
                of: "<tool_call>", with: "")
        }
        
        logger.debug("Adding to buffer: \(tokenText)")
        toolCallBuffer += tokenText
        
        if toolCallBuffer.contains("</tool_call>") {
            logger.info("Complete tool call received, processing")
            toolCallBuffer = toolCallBuffer.replacingOccurrences(
                of: "</tool_call>", with: "")
            let jsonString = toolCallBuffer.trimmingCharacters(
                in: .whitespacesAndNewlines)
            
            logger.debug("Processing JSON string: \(jsonString)")
            let result = try await handleToolCall(jsonString)
            logger.debug("Tool call processed successfully with result: \(result)")
            
            toolCallBuffer = ""
            return result
        }
        throw ToolCallError.invalidArguments
    }
    
    private func handleToolCall(_ jsonString: String) async throws -> String {
        logger.debug("Handling tool call with JSON: \(jsonString)")
        guard let data = jsonString.data(using: .utf8) else {
            logger.error("Failed to convert JSON string to data")
            throw ToolCallError.invalidJSON
        }
        
        let toolCall = try decoder.decode(ToolCall.self, from: data)
        logger.info("Successfully decoded tool call with name: \(toolCall.name.rawValue)")
        
        return try await processToolCallArgument(with: toolCall.name, argument: toolCall.arguments)
    }
    
    private func processToolCallArgument(with name: ToolCallType, argument: ToolCallArguments) async throws -> String {
        logger.info("Processing tool call: \(name.rawValue) with arguments")
        let result: String
        switch (name, argument) {
        case (.getWorkoutSummary, .workout):
            logger.debug("Fetching workout data")
            result = try await fetchWorkoutData()
            
        case (.getWeatherData, .weather(let args)):
            logger.debug("Fetching weather data for location: \(args.location)")
            result = try await fetchWeatherData(for: args.location)
            
        case (.searchDuckDuckGo, .search(let args)):
            logger.debug("Performing search for query: \(args.query)")
            result = try await performSearch(for: args.query)
            
        default:
            logger.error("Invalid argument combination: \(name.rawValue)")
            throw ToolCallError.invalidArguments
        }
        logger.info("Successfully processed tool call with result length: \(result.count)")
        
        return result
    }
    
    private func handleLlamaFormat(_ text: String) async throws -> String {
        logger.debug("Handling Llama format for text: \(text)")
        
        guard let startRange = text.range(of: "<|python_tag|>"),
              let endRange = text.range(of: "<|eom_id|>") else {
            logger.error("Invalid Llama format: missing required tags")
            throw ToolCallError.invalidArguments
        }
        
        let startIndex = startRange.upperBound
        let endIndex = endRange.lowerBound
        
        let jsonString = String(text[startIndex..<endIndex])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        logger.debug("Extracted JSON from Llama format: '\(jsonString)'")
        
        guard let data = jsonString.data(using: .utf8) else {
            logger.error("Failed to convert Llama JSON string to data")
            throw ToolCallError.invalidJSON
        }
        
        let llamaCall = try decoder.decode(LlamaToolCall.self, from: data)        
        logger.info("Successfully decoded Llama tool call with name: \(llamaCall.name.rawValue)")
        return try await processToolCallArgument(with: llamaCall.name, argument: llamaCall.parameters)
    }
    
    private func fetchWorkoutData() async throws -> String {
        logger.debug("Fetching workout data")
        let workouts = try await healthManager.fetchWorkouts(for: .week(Date()))
        if workouts.isEmpty {
            logger.info("No workouts found for this week")
            return "No workouts found for this week."
        }
        logger.info("Workout data fetched successfully")
        return OutputFormatter.formatWeeklyWorkoutSummary(
            workouts, using: healthManager)
    }
    
    private func fetchWeatherData(for location: String) async throws -> String {
        logger.debug("Fetching weather data for location: \(location)")
        loadingManager.startLoading(
            message: "Fetching weather data for \(location)...")
        
        do {
            let weather = try await weatherManager.fetchWeather(
                forCity: location)
            loadingManager.stopLoading()
            logger.info("Weather data fetched successfully for location: \(location)")
            return OutputFormatter.formatWeatherData(weather)
        } catch {
            loadingManager.stopLoading()
            logger.error("Failed to fetch weather data for location: \(location)")
            throw error
        }
    }
    
    private func performSearch(for query: String) async throws -> String {
        logger.debug("Performing search for query: \(query)")
        loadingManager.startLoading(
            message: "Searching DuckDuckGo for \(query)...")
        
        do {
            let results = try await searchManager.search(query: query)
            loadingManager.stopLoading()
            logger.info("Search results fetched successfully for query: \(query)")
            return results
        } catch {
            loadingManager.stopLoading()
            logger.error("Failed to fetch search results for query: \(query)")
            throw error
        }
    }
}

enum ToolCallError: Error, Equatable {
    case invalidJSON
    case invalidArguments
    case unknownTool(String)
}
