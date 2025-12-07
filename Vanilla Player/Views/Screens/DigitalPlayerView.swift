import SwiftUI

struct DigitalPlayerView: View {
    @State private var selectedTab = 0

    @EnvironmentObject var viewModel: PlayerViewModel

    var body: some View {
        VStack(alignment: .center) {
            Spacer()
                .frame(height: 24)

            let textColor = Color(hex: "#c0a06c")

            CenteredTabView(
                tabs: ["Now Playing", "Songs"],
                selectedIndex: $selectedTab,
                selectedTextColor: textColor,
                unselectedTextColor: textColor.opacity(0.5), // Slightly dimmed for unselected
                onTabChange: { index in selectedTab = index }
            )

            // Content Area
            ZStack {
                if selectedTab == 0 {
                    DigitalNowPlayingView()
                        .transition(.opacity)
                } else {
                    TrackListView()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut, value: selectedTab)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .cornerRadius(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "#21160f").opacity(0.36),
                            Color(hex: "#21160f").opacity(0.52),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(
                    color: Color.black.opacity(0.8),
                    radius: 10,
                    x: -4,
                    y: 4
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            .white.opacity(0.08), .white.opacity(0.15),
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 2
                )
        )
    }
}

#Preview {
    DigitalPlayerView()
        .environmentObject(PlayerViewModel())
}
