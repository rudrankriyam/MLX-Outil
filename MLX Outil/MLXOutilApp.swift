//
//  MLXOutilApp.swift
//  MLX Outil
//
//  Created by Rudrank Riyam on 12/1/24.
//

import SwiftUI

@main
struct MLXOutilApp: App {
  @State private var evaluator = UnifiedEvaluator()

  var body: some Scene {
    WindowGroup {
      MainTabView()
        .environment(evaluator)
    }
  }
}
