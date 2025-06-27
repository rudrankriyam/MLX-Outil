import Foundation
import MLXLMCommon
import MLXTools
import Tokenizers
import os

@MainActor
class ToolManager {
    static let shared = ToolManager()
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "MLXOutil", category: "ToolManager")
    
    private init() {
        logger.info("ToolManager initialized")
        logger.info("All tools initialized")
    }
    
    // MARK: - Tool Registry
    
    var allTools: [any ToolProtocol] {
        let tools: [any ToolProtocol] = [
            weatherTool, 
            workoutTool, 
            searchTool,
            calendarTool,
            remindersTool,
            contactsTool,
            locationTool,
            musicTool
        ]
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
                
            case "manage_calendar":
                logger.debug("Executing calendar tool")
                let result = try await toolCall.execute(with: calendarTool)
                logger.info("Calendar tool executed successfully")
                return try result.toolResult
                
            case "manage_reminders":
                logger.debug("Executing reminders tool")
                let result = try await toolCall.execute(with: remindersTool)
                logger.info("Reminders tool executed successfully")
                return try result.toolResult
                
            case "manage_contacts":
                logger.debug("Executing contacts tool")
                let result = try await toolCall.execute(with: contactsTool)
                logger.info("Contacts tool executed successfully")
                return try result.toolResult
                
            case "access_location":
                logger.debug("Executing location tool")
                let result = try await toolCall.execute(with: locationTool)
                logger.info("Location tool executed successfully")
                return try result.toolResult
                
            case "access_music":
                logger.debug("Executing music tool")
                let result = try await toolCall.execute(with: musicTool)
                logger.info("Music tool executed successfully")
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