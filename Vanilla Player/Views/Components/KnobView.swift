import SwiftUI

struct KnobView: View {
    let buttonSize: Double
    let startAngle: Double
    let endAngle: Double

    @Binding var progress: Double

    @State private var isDragging = false
    @State private var lastDragAngle = 0.0

    var body: some View {
        ZStack {
            Image("knob")
                .resizable()
                .frame(width: buttonSize, height: buttonSize)
                .cornerRadius(buttonSize)
                .shadow(
                    color: Color.black.opacity(0.8),
                    radius: 4,
                    x: -1,
                    y: 2
                )
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if isDragging {
                                onDragging(value: value)
                            } else {
                                onDragStarted(value: value)
                                isDragging = true
                            }
                        }
                        .onEnded { _ in
                            onDragEnded()
                            isDragging = false
                        }
                )

            let indicatorColor = Color(hex: "#d6b577")

            let rotation = startAngle + (endAngle - startAngle) * progress

            let r = buttonSize / 2
            let radians = rotation * .pi / 180
            let dx = r * cos(radians) * 0.65
            let dy = r * sin(radians) * 0.65

            // Progress indicator
            let indicatorWidth = buttonSize * 0.04
            let indicatorHeight = buttonSize * 0.16
            RoundedRectangle(cornerRadius: 4)
                .fill(indicatorColor)
                .frame(width: indicatorWidth, height: indicatorHeight)
                .cornerRadius(4)
                .rotationEffect(.degrees(90 + rotation))
                .offset(x: dx, y: dy)

            let startRadians = startAngle * .pi / 180
            let startIndicatorDx = r * cos(startRadians) * 1.1
            let startIndicatorDy = r * sin(startRadians) * 1.1
            Circle()
                .fill(indicatorColor)
                .frame(width: indicatorWidth, height: indicatorWidth)
                .opacity(0.5)
                .allowsHitTesting(false)
                .offset(x: startIndicatorDx, y: startIndicatorDy)

            let endRadians = endAngle * .pi / 180
            let endIndicatorDx = r * cos(endRadians) * 1.1
            let endIndicatorDy = r * sin(endRadians) * 1.1
            Circle()
                .fill(indicatorColor)
                .frame(width: indicatorWidth * 2, height: indicatorWidth * 2)
                .opacity(0.5)
                .offset(x: endIndicatorDx, y: endIndicatorDy)
        }
        .padding(16)
    }

    private func onDragStarted(value: DragGesture.Value) {
        lastDragAngle = calcAngle(x: value.location.x, y: value.location.y)
    }

    private func onDragging(value: DragGesture.Value) {
        let currAngle = calcAngle(x: value.location.x, y: value.location.y)
        let angleChange = normalizeAngle(currAngle - lastDragAngle)
        let progressChange = -angleChange / (endAngle - startAngle)
        progress = min(1, max(0, progress + progressChange))
        lastDragAngle = currAngle
    }

    private func onDragEnded() {
        lastDragAngle = 0
    }

    private func calcAngle(x: Double, y: Double) -> Double {
        return atan2(x - buttonSize / 2, y - buttonSize / 2) * 180 / Double.pi
    }

    private func normalizeAngle(_ angle: Double) -> Double {
        var normalized = angle
        while normalized > Double.pi {
            normalized -= 2 * Double.pi
        }
        while normalized < -Double.pi {
            normalized += 2 * Double.pi
        }
        return normalized
    }
}

#Preview {
    @Previewable @State var progress = 0.0
    KnobView(buttonSize: 200, startAngle: 0, endAngle: 260, progress: $progress)
        .padding()
}
