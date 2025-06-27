# Instructions to Add MLXTools as Local Package Dependency

Since you're using Xcode with the new build system, you'll need to add the local package dependency through Xcode's GUI:

## Steps:

1. **Open MLX Outil.xcodeproj in Xcode**

2. **Add Local Package Dependency:**
   - Select the MLX Outil project in the navigator
   - Select the "MLX Outil" target
   - Go to the "General" tab
   - Scroll to "Frameworks, Libraries, and Embedded Content"
   - Click the "+" button
   - In the dialog, click "Add Other..." → "Add Package Dependency..."
   - Click "Add Local..."
   - Navigate to the MLX-Outil folder (the root of this repository)
   - Select it and click "Add Package"
   - In the package products dialog, select "MLXTools"
   - Click "Add"

3. **Remove Old Files:**
   - In Xcode, delete these files (move to trash):
     - MLX Outil/Services/WeatherKitManager.swift
     - MLX Outil/Services/HealthKitManager.swift
     - MLX Outil/Services/DuckDuckGoManager.swift
     - MLX Outil/Utilities/OutputFormatter.swift
     - MLX Outil/Utilities/Constants.swift

4. **Update ToolManager.swift:**
   - Open MLX Outil/Services/ToolManager.swift
   - Add `import MLXTools` at the top
   - Remove the local tool definitions and use the ones from MLXTools:

```swift
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
```

5. **Build and Test:**
   - Build the project (⌘B)
   - Run the app to ensure everything works correctly

## Note

After completing these steps, the MLXTools package will be available as a local dependency, and all the system tools will be imported from the package instead of being duplicated in the main project.