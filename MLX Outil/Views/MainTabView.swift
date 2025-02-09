//
//  MainTabView.swift
//  MLX Outil
//
//  Created by Rudrank Riyam on 2/9/25.
//

import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            WorkoutView()
                .tabItem {
                    Label("Workouts", systemImage: "figure.run")
                }

            WeatherView()
                .tabItem {
                    Label("Weather", systemImage: "cloud.sun")
                }
        }
    }
}

#Preview {
    MainTabView()
}
