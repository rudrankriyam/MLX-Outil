//
//  MainTabView.swift
//  MLX Outil
//
//  Created by Rudrank Riyam on 2/9/25.
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var llm: UnifiedEvaluator

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
        }
    }
}

#Preview {
    MainTabView()
}
