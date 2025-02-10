# MLX Outil

MLX Outil is a multiplatform Swift project to show tool usage with Qwen 2.5 1.5B model using MLX Swift across iOS, macOS, and visionOS platforms.

![Platforms](https://img.shields.io/badge/Platforms-iOS%2016.0+%20|%20macOS%2013.0+%20|%20visionOS%201.0+-lightgrey)
![Swift](https://img.shields.io/badge/Swift-6.0-orange)
![MLX](https://img.shields.io/badge/MLX-latest-blue)

## Features

- Tool use demonstrations using Qwen 2.5 1.5B model
- Cross-platform support (iOS, macOS, visionOS)
- On-device inference using MLX Swift
- Example tools implementation:
  - Weather information (You will have to provide your own bundle identifier which has WeatherKit checked)
  - Workout summary data (still implementing)

## Requirements

- Xcode 15.0+
- iOS 16.0+
- macOS 13.0+
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
