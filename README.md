# MLX Outil

MLX Outil is a multiplatform Swift project to show tool usage with Qwen 2.5 1.5B and Llama 3 seris model using MLX Swift across iOS, macOS, and visionOS platforms.

The name **MLX Outil** is derived from the French word *outil*, which means "tool."

![Platforms](https://img.shields.io/badge/Platforms-iOS%2017.0+%20|%20macOS%2014.0+%20|%20visionOS%201.0+-lightgrey)
![Swift](https://img.shields.io/badge/Swift-6.0-orange)
![MLX](https://img.shields.io/badge/MLX-latest-blue)

## Support

Love this project? Check out my books to explore more of AI and iOS development:
- [Exploring AI for iOS Development](https://academy.rudrank.com/product/ai)
- [Exploring AI-Assisted Coding for iOS Development](https://academy.rudrank.com/product/ai-assisted-coding)

Your support helps to keep this project growing!

## Features

- Tool use demonstrations using Llama 3.2 3B model
- Cross-platform support (iOS, macOS, visionOS)
- On-device inference using MLX Swift
- **MLXTools**: A modular Swift package providing system integration tools
- Example tools implementation:
  - Weather information (You will have to provide your own bundle identifier which has WeatherKit checked)
  - Workout summary data
  - Web search with Duck Duck Go

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

4. Build and run the project

## Project Structure

### MLXTools Package

The project includes a modular Swift package called `MLXTools` that provides:

- **WeatherKitManager**: Weather data integration with OpenMeteo fallback
- **HealthKitManager**: Access to workout and health data
- **DuckDuckGoManager**: Web search functionality
- **Tool Definitions**: Pre-configured MLXLMCommon tool definitions for LLM integration

The package is designed to be reusable and follows MLX naming conventions, making it easy to share with the open-source community.

## Usage

```swift
// Initialize view with SwiftUI
MLXOutilView()
    .environmentObject(MLXModel())
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contact
For questions and support, please open an issue in the repository.
