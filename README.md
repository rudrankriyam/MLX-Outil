# MLX Outil
[![Star History Chart](https://api.star-history.com/svg?repos=rudrankriyam/MLX-Outil&type=Date)](https://star-history.com/#rudrankriyam/MLX-Outil&Date)


MLX Outil is a multiplatform Swift project to show tool usage with Qwen 3 1.7B model using MLX Swift across iOS, macOS, and visionOS platforms.

The name **MLX Outil** is derived from the French word *outil*, which means "tool."

![Platforms](https://img.shields.io/badge/Platforms-iOS%2017.0+%20|%20macOS%2014.0+%20|%20visionOS%201.0+-lightgrey)
![Swift](https://img.shields.io/badge/Swift-6.2-orange)
![MLX](https://img.shields.io/badge/MLX-latest-blue)

## Support

Love this project? Check out my books to explore more of AI and iOS development:
- [Exploring AI for iOS Development](https://academy.rudrank.com/product/ai)
- [Exploring AI-Assisted Coding for iOS Development](https://academy.rudrank.com/product/ai-assisted-coding)

Your support helps to keep this project growing!

## Features

- Tool use demonstrations using Qwen 3 1.7B model
- Cross-platform support (iOS, macOS, visionOS)
- On-device inference using MLX Swift
- **MLXTools**: A modular Swift package providing system integration tools
- Comprehensive tool implementations:
  - **Weather**: Weather information with WeatherKit and OpenMeteo fallback
  - **Health**: Workout summary data via HealthKit
  - **Web Search**: Duck Duck Go integration
  - **Calendar**: Event management and scheduling
  - **Contacts**: Contact search, creation, and management
  - **Location**: GPS, geocoding, and distance calculations
  - **Music**: Apple Music search and playback control
  - **Reminders**: Task and reminder management

## Requirements

- Xcode 15.0+
- iOS 17.0+
- macOS 14.0+
- visionOS 1.0+
- Swift 6.0
- MLX Swift (latest version)

## Installation

1. Clone the repository:
```bash
git clone https://github.com/rudrankriyam/mlx-outil.git
cd mlx-outil
```

2. Open `MLXOutil.xcodeproj` in Xcode

3. Ensure you have the necessary permissions set up in your target's capabilities:
   - HealthKit (for workout tracking features)
   - WeatherKit (for weather data)
   - Location Services (for current location weather)
   - Contacts (for contact management)
   - EventKit (for calendar and reminders)
   - MusicKit (for Apple Music integration)

4. Build and run the project

## Project Structure

### MLXTools Package

The project includes a modular Swift package called `MLXTools` that provides:

- **WeatherKitManager**: Weather data integration with OpenMeteo fallback
- **HealthKitManager**: Access to workout and health data
- **DuckDuckGoManager**: Web search functionality
- **CalendarManager**: Calendar event management using EventKit
- **ContactsManager**: Contact operations using Contacts framework
- **LocationManager**: Location services and geocoding with CoreLocation
- **MusicManager**: Apple Music search and playback with MusicKit
- **RemindersManager**: Reminder and task management using EventKit
- **Tool Definitions**: Pre-configured MLXLMCommon tool definitions for LLM integration

The package is designed to be reusable and follows MLX naming conventions, making it easy to share with the open-source community.

### Adding MLXTools as a Dependency

#### Swift Package Manager

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

#### Local Development

For local development, you can add the package as a local dependency:

```swift
dependencies: [
    .package(path: "../MLXTools")
]
```

## Usage

### Basic App Usage

```swift
// Initialize view with SwiftUI
MLXOutilView()
    .environmentObject(MLXModel())
```

### MLXTools Usage Examples

#### Weather Data

```swift
import MLXTools

// Using the manager directly
let weather = try await WeatherKitManager.shared.fetchWeather(forCity: "San Francisco, CA")
print("Temperature: \(weather.temperature)°C")

// Using the tool definition for LLM integration
let weatherTool = weatherTool // Pre-configured tool
```

#### Health Data

```swift
import MLXTools

// Request authorization first
try await HealthKitManager.shared.requestAuthorization()

// Fetch workouts for the current week
let workouts = try await HealthKitManager.shared.fetchWorkouts(for: .week(Date()))

// Format workout summary
let summary = OutputFormatter.formatWeeklyWorkoutSummary(workouts, using: HealthKitManager.shared)
```

#### Web Search

```swift
import MLXTools

// Search using DuckDuckGo
let results = try await DuckDuckGoManager.shared.search(query: "Swift programming")
print(results)
```

#### Calendar Management

```swift
import MLXTools

// Create a calendar event
let calendarInput = CalendarInput(
    action: "create",
    title: "Team Meeting",
    startDate: "2024-01-15 14:00:00",
    endDate: "2024-01-15 15:00:00",
    location: "Conference Room A",
    notes: "Weekly team sync"
)
let result = try await CalendarManager.shared.performAction(calendarInput)

// Query upcoming events
let queryInput = CalendarInput(action: "query", daysAhead: 7)
let events = try await CalendarManager.shared.performAction(queryInput)
```

#### Contact Management

```swift
import MLXTools

// Search for contacts
let searchInput = ContactsInput(action: "search", query: "John")
let contacts = try await ContactsManager.shared.performAction(searchInput)

// Create a new contact
let createInput = ContactsInput(
    action: "create",
    givenName: "Jane",
    familyName: "Doe",
    email: "jane.doe@example.com",
    phoneNumber: "+1234567890"
)
let newContact = try await ContactsManager.shared.performAction(createInput)
```

#### Location Services

```swift
import MLXTools

// Get current location
let currentInput = LocationInput(action: "current")
let location = try await LocationManager.shared.performAction(currentInput)

// Geocode an address
let geocodeInput = LocationInput(action: "geocode", address: "1 Apple Park Way, Cupertino, CA")
let coordinates = try await LocationManager.shared.performAction(geocodeInput)

// Calculate distance between two points
let distanceInput = LocationInput(
    action: "distance",
    latitude: 37.7749,
    longitude: -122.4194,
    latitude2: 37.3349,
    longitude2: -122.0090
)
let distance = try await LocationManager.shared.performAction(distanceInput)
```

#### Music Control

```swift
import MLXTools

// Search for music
let searchInput = MusicInput(action: "search", query: "Taylor Swift", limit: 5)
let searchResults = try await MusicManager.shared.performAction(searchInput)

// Play music
let playInput = MusicInput(action: "play", itemId: "song-id-from-search")
let playResult = try await MusicManager.shared.performAction(playInput)

// Get current playing song
let currentInput = MusicInput(action: "currentSong")
let nowPlaying = try await MusicManager.shared.performAction(currentInput)
```

#### Reminders Management

```swift
import MLXTools

// Create a reminder
let createInput = RemindersInput(
    action: "create",
    title: "Buy groceries",
    notes: "Milk, bread, eggs",
    dueDate: "2024-01-16 18:00:00",
    priority: "high"
)
let reminder = try await RemindersManager.shared.performAction(createInput)

// Query reminders
let queryInput = RemindersInput(action: "query", filter: "incomplete")
let reminders = try await RemindersManager.shared.performAction(queryInput)

// Complete a reminder
let completeInput = RemindersInput(action: "complete", reminderId: "reminder-id")
let completed = try await RemindersManager.shared.performAction(completeInput)
```

#### LLM Tool Integration

MLXTools provides pre-configured tool definitions for use with MLXLMCommon:

```swift
import MLXTools
import MLXLMCommon

// Available tools
let tools: [any ToolProtocol] = [
    weatherTool,    // Weather data tool
    workoutTool,    // Workout summary tool
    searchTool,     // Web search tool
    calendarTool,   // Calendar management tool
    contactsTool,   // Contacts management tool
    locationTool,   // Location services tool
    musicTool,      // Music control tool
    remindersTool   // Reminders management tool
]

// Use with your LLM
let userInput = UserInput(
    chat: messages,
    tools: tools
)
```

## Entitlements

The following entitlements are required for full functionality:

- **HealthKit**: For accessing workout data
- **WeatherKit**: For weather data (falls back to OpenMeteo if unavailable)
- **Location Services**: For current location weather and location tools
- **Contacts**: For contact management features
- **EventKit**: For calendar and reminders access
- **MusicKit**: For Apple Music integration

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contact
For questions and support, please open an issue in the repository.
