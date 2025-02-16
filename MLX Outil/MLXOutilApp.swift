import SwiftUI

@main
struct MLXOutilApp: App {
    @State private var llmManager = LLMManager()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(llmManager)
        }
    }
}
