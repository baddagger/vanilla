import SwiftUI

struct PlaybackSliderView: View {
    @Binding var currentTime: TimeInterval
    let duration: TimeInterval
    let onSeek: (TimeInterval) -> Void
    
    var body: some View {
        VStack(spacing: 4) {
            let trackColor = Color(hex: "#c0a06c")
            let thumbColor = Color(hex: "#e8c890")
            let newColor = Color(hex: "#d2af74")

            GeometryReader { geometry in
                let progress =
                    duration > 0
                    ? currentTime / duration : 0
                let thumbSize: CGFloat = 16
                let trackHeight: CGFloat = 4
                let thumbOffset =
                    (geometry.size.width - thumbSize) * CGFloat(progress)

                ZStack(alignment: .leading) {
                    // Track background (unfilled portion)
                    Capsule()
                        .fill(Color.gray.opacity(0.4))
                        .frame(height: trackHeight)

                    // Track filled portion
                    Capsule()
                        .fill(trackColor)
                        .frame(
                            width: geometry.size.width * CGFloat(progress),
                            height: trackHeight
                        )

                    // Thumb
                    Circle()
                        .fill(thumbColor)
                        .frame(width: thumbSize, height: thumbSize)
                        .offset(x: thumbOffset)
                }
                .frame(height: geometry.size.height)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let percent = max(
                                0,
                                min(
                                    1,
                                    value.location.x / geometry.size.width
                                )
                            )
                            onSeek(Double(percent) * duration)
                        }
                )
            }
            .frame(height: 20)

            HStack {
                Text(formatTime(currentTime))
                Spacer()
                Text(formatTime(duration))
            }
            .font(.caption)
            .foregroundColor(newColor)
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
