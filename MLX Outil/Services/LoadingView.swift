import SwiftUI

struct LoadingView: View {
    @StateObject private var loadingManager = LoadingManager.shared

    var body: some View {
        if loadingManager.isLoading {
            VStack(spacing: 24) {
                // Content shimmer boxes
                VStack(alignment: .leading, spacing: 16) {
                    ShimmerView()
                        .frame(height: 24)

                    ShimmerView()
                        .frame(height: 100)

                    HStack(spacing: 12) {
                        ShimmerView()
                            .frame(width: 60, height: 60)

                        VStack(alignment: .leading, spacing: 8) {
                            ShimmerView()
                                .frame(height: 20)
                                .frame(width: 120)

                            ShimmerView()
                                .frame(height: 20)
                                .frame(width: 80)
                        }
                    }
                }
                .padding(.horizontal)

                Text(loadingManager.loadingMessage)
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }
            .frame(maxWidth: 300)
            .padding(.vertical)
        }
    }
}

#Preview {
    LoadingView()
        .environmentObject(LoadingManager.shared)
}

// End of file
