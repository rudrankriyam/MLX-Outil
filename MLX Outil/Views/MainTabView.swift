import SwiftUI

struct MainTabView: View {
  @Environment(LLMManager.self) var llm

  var body: some View {
    TabView {
      WeatherView()
        .tabItem {
          Label("Weather", systemImage: "cloud.sun")
        }

      WorkoutView()
        .tabItem {
          Label("Workouts", systemImage: "figure.run")
        }

      SearchView()
        .tabItem {
          Label("Search", systemImage: "magnifyingglass")
        }
    }
  }
}
