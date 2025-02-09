import Foundation

class LoadingManager: ObservableObject {
    static let shared = LoadingManager()
    
    @Published var isLoading = false
    @Published var loadingMessage = ""
    
    private init() {}
    
    func startLoading(message: String = "Loading...") {
        DispatchQueue.main.async {
            self.loadingMessage = message
            self.isLoading = true
        }
    }
    
    func stopLoading() {
        DispatchQueue.main.async {
            self.isLoading = false
            self.loadingMessage = ""
        }
    }
}

// End of file
