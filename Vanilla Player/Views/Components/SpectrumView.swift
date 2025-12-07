import SwiftUI

struct SpectrumView: View {
    @ObservedObject var viewModel: VisualizerViewModel

    private let gradient = LinearGradient(
        gradient: Gradient(stops: [
            .init(
                color: Color(hex: "#dbbe83"),
                location: 0.0
            ),  // Bright cream at top
            .init(
                color: Color(hex: "#d8b86c"),
                location: 0.15
            ),  // Light gold
            .init(
                color: Color(hex: "#af905d"),
                location: 0.5
            ),  // Darker gold in middle
            .init(
                color: Color(hex: "#d8b86c"),
                location: 0.85
            ),  // Light gold
            .init(
                color: Color(hex: "#dbbe83"),
                location: 1.0
            ),  // Bright cream at bottom
        ]),
        startPoint: .top,
        endPoint: .bottom
    )

    var body: some View {
        GeometryReader { geometry in
            HStack {
                let levels = viewModel.meteringLevels
                ForEach(0..<levels.count, id: \.self) {
                    index in
                    let height = geometry.size.height
                    let level = CGFloat(levels[index])
                    let barHeight = max(6, height * level)

                    ZStack {
                        // Main bar with gradient - brighter at both ends
                        Capsule()
                            .fill(gradient)
                            .frame(width: 2.6, height: barHeight)

                        // Top highlight for "lit" effect
                        Capsule()
                            .fill(Color.white.opacity(0.25))
                            .frame(width: 2, height: min(6, barHeight * 0.3))
                            .offset(y: -barHeight / 2 + 3)

                        // Bottom highlight for "lit" effect
                        Capsule()
                            .fill(Color.white.opacity(0.25))
                            .frame(width: 2, height: min(6, barHeight * 0.3))
                            .offset(y: barHeight / 2 - 3)
                    }
                    .animation(.linear(duration: 0.04), value: barHeight)
                    .frame(height: height)
                    
                    if index < levels.count - 1 {
                        Spacer()
                    }
                }
            }
        }
    }
}

#Preview {
    let mockAudio = AudioEngineManager()
    let mockVM = VisualizerViewModel(audioManager: mockAudio)
    SpectrumView(viewModel: mockVM)
        .frame(height: 50)
        .padding()
        .background(Color.black)
}
