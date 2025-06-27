# MLXTools

A Swift package providing system integration tools for MLX applications on Apple platforms.

## Features

- **Weather Integration**: Fetch weather data using WeatherKit with OpenMeteo fallback
- **Health Integration**: Access workout data from HealthKit
- **Web Search**: Search the web using DuckDuckGo API
- **Tool Definitions**: Pre-configured MLXLMCommon tool definitions for LLM integration

## Installation

### Swift Package Manager

Add MLXTools as a dependency in your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/MLXTools", branch: "main")
]
```

Or add it directly in Xcode:
1. File → Add Package Dependencies
2. Enter the repository URL
3. Select "main" branch

### Local Development

For local development, you can add the package as a local dependency:

```swift
dependencies: [
    .package(path: "../MLXTools")
]
```

## Usage

### Weather Data

```swift
import MLXTools

// Using the manager directly
let weather = try await WeatherKitManager.shared.fetchWeather(forCity: "San Francisco, CA")
print("Temperature: \(weather.temperature)°C")

// Using the tool definition for LLM integration
let weatherTool = weatherTool // Pre-configured tool
```

### Health Data

```swift
import MLXTools

// Request authorization first
try await HealthKitManager.shared.requestAuthorization()

// Fetch workouts for the current week
let workouts = try await HealthKitManager.shared.fetchWorkouts(for: .week(Date()))

// Format workout summary
let summary = OutputFormatter.formatWeeklyWorkoutSummary(workouts, using: HealthKitManager.shared)
```

### Web Search

```swift
import MLXTools

// Search using DuckDuckGo
let results = try await DuckDuckGoManager.shared.search(query: "Swift programming")
print(results)
```

### LLM Tool Integration

MLXTools provides pre-configured tool definitions for use with MLXLMCommon:

```swift
import MLXTools
import MLXLMCommon

// Available tools
let tools: [any ToolProtocol] = [
    weatherTool,    // Weather data tool
    workoutTool,    // Workout summary tool
    searchTool      // Web search tool
]

// Use with your LLM
let userInput = UserInput(
    chat: messages,
    tools: tools
)
```

## Requirements

- iOS 17.0+ / macOS 14.0+
- Swift 6.0+
- Xcode 16.0+

## Entitlements

The following entitlements are required:

- **HealthKit**: For accessing workout data
- **WeatherKit**: For weather data (falls back to OpenMeteo if unavailable)
- **Location Services**: For current location weather

## License

[Add your license here]