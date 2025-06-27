# MLX Outil Tool System Documentation

## Overview

MLX Outil now uses MLXLMCommon's tool infrastructure for handling tool calls in LLM responses. This provides a standardized way to define, register, and execute tools.

## Architecture

### Key Components

1. **ToolManager** - Central registry for all available tools
2. **ToolCallProcessor** - Processes LLM output to detect and parse tool calls
3. **Tool Definitions** - Strongly typed tool definitions using MLXLMCommon's `Tool` type

### Tool Flow

1. LLM generates output containing `<tool_call>` tags
2. `ToolCallProcessor.processChunk()` detects and parses tool calls
3. `ToolManager.execute()` executes the appropriate tool
4. Results are formatted and fed back to the LLM for continuation

## Adding New Tools

To add a new tool:

1. Define input/output types in ToolManager:
```swift
struct MyToolInput: Codable, Sendable {
    let parameter: String
}

struct MyToolOutput: Codable, Sendable {
    let result: String
}
```

2. Create the tool definition:
```swift
let myTool = Tool<MyToolInput, MyToolOutput>(
    name: "my_tool_name",
    description: "Description of what the tool does",
    parameters: [
        .required("parameter", type: .string, description: "Parameter description")
    ]
) { input in
    // Tool implementation
    return MyToolOutput(result: "processed: \(input.parameter)")
}
```

3. Add to `allTools` array in ToolManager
4. Add execution case in `ToolManager.execute()`

## Tool Types

### Weather Tool
- **Name**: `get_weather_data`
- **Input**: Location string
- **Output**: WeatherData object
- **Usage**: Fetches current weather for a specified location

### Workout Tool
- **Name**: `get_workout_summary`
- **Input**: None
- **Output**: Weekly workout summary string
- **Usage**: Retrieves and formats workout data from HealthKit

### Search Tool
- **Name**: `search_duckduckgo`
- **Input**: Search query string
- **Output**: Search results string
- **Usage**: Performs web search via DuckDuckGo

## Error Handling

The system provides comprehensive error handling:

- `ToolError.nameMismatch` - Tool name doesn't match function call
- `ToolManagerError.unknownTool` - Tool not found in registry
- `ToolManagerError.toolExecutionFailed` - Tool execution error with details

## Example Usage

```swift
// In LLMManager
let userInput = UserInput(
    chat: messages,
    tools: includingTools ? availableTools : []
)

// Tool calls are automatically detected and executed during streaming
for await batch in stream {
    if let chunk = batch.chunk {
        if let processedText = toolCallProcessor.processChunk(chunk) {
            // Regular text output
            self.output += processedText
        }
        
        // Tool calls are handled automatically
    }
}
```

## Migration from Custom Implementation

The previous custom `ToolCallHandler` has been replaced with MLXLMCommon's infrastructure:

- Custom parsing logic → `ToolCallProcessor`
- Manual JSON decoding → `ToolCall.execute()`
- Custom error types → Standard `ToolError` types
- Static tool definitions → Type-safe `Tool<Input, Output>` definitions