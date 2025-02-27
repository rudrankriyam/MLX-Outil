# MLXArguments

A generic Swift Package for handling tool call arguments in MLX-Outil.

## Overview

MLXArguments provides a protocol-based approach for handling tool calls in MLX-powered apps. By conforming to the provided protocols, you can easily extend your app with custom tools that can be called by language models.

## Core Components

- `ToolCallTypeProtocol`: Protocol for defining different types of tools
- `ArgumentProtocol`: Protocol for defining arguments that tools can accept
- `ToolCallHandlerProtocol`: Protocol for handling tool calls from language models
- `BaseToolCallHandler`: Base implementation for processing tool calls
- `ToolRegistry`: Registry for tool types and their handlers

## Usage

### 1. Register Tool Handlers

```swift
// Create tool handlers
let weatherHandler = WeatherToolHandler(weatherService: MyWeatherService())
let searchHandler = SearchToolHandler(searchService: MySearchService())

// Register handlers with the registry
ToolRegistry.shared.register(toolType: WeatherToolType.getWeatherData, handler: weatherHandler)
ToolRegistry.shared.register(toolType: SearchToolType.searchDuckDuckGo, handler: searchHandler)
```

### 2. Create a Custom Tool Call Handler

```swift
class MyToolCallHandler: BaseToolCallHandler {
    override func handleToolCall(_ jsonString: String) async throws -> String {
        guard let data = jsonString.data(using: .utf8) else {
            throw ToolCallError.invalidJSON
        }
        
        // First try to decode just the tool name
        struct ToolName: Codable {
            let name: String
        }
        
        let toolNameInfo = try JSONDecoder().decode(ToolName.self, from: data)
        
        guard let handler = ToolRegistry.shared.handler(for: toolNameInfo.name) else {
            throw ToolCallError.unknownTool(toolNameInfo.name)
        }
        
        return try await handler.handle(json: data)
    }
}
```

### 3. Use the Tool Call Handler with Your LLM

```swift
let toolCallHandler = MyToolCallHandler()
let processedText = try await toolCallHandler.processLLMOutput(llmOutput)
```

## Creating Custom Tools

1. Define a tool type that conforms to `ToolCallTypeProtocol`
2. Create an arguments struct that conforms to `ArgumentProtocol`
3. Implement a handler that conforms to `ToolRegistry.ToolHandlerProtocol`
4. Register the handler with the `ToolRegistry`

See the `SampleTools` directory for examples.
