import SwiftUI

struct MainTabView: View {
  @Environment(LLMManager.self) var llm

  var body: some View {
    TabView {
      ExamplesView()
        .tabItem {
          Label("Examples", systemImage: "sparkles")
        }

      ToolsGridView()
        .tabItem {
          Label("Tools", systemImage: "wrench.and.screwdriver")
        }
    }
  }
}
