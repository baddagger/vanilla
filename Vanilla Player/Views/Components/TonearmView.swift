import SwiftUI

struct TonearmView: View {
    let startAngle: Double
    let endAngle: Double
    let idleAngle: Double

    @Binding var playbackProgress: Double

    @State private var isDragging = false
    @State private var lastDragAngle = 0.0

    // Layout constants
    private let rotationAnchorX = 0.76
    private let rotationAnchorY = 0.2

    // Drag handle constants (relative to height)
    private let handleWidthRatio = 0.08
    private let handleHeightRatio = 0.22
    private let handleOffsetXRatio = -0.234
    private let handleOffsetYRatio = 0.367
    private let handleRotation = 54.0

    var body: some View {
        let angle = playbackProgress < 0 ? idleAngle : startAngle + (endAngle - startAngle) * playbackProgress

        ZStack {
            GeometryReader { geometry in
                let height = geometry.size.height

                let baseSize = height * 0.379
                let offsetX = height * 0.32
                let offsetY = height * 0.024

                Image("tonearmBase")
                    .resizable()
                    .frame(width: baseSize, height: baseSize)
                    .offset(x: offsetX, y: offsetY)
                    .shadow(
                        color: Color.black.opacity(0.8),
                        radius: 6,
                        x: -4,
                        y: 6
                    )

                Image("tonearm")
                    .resizable()
                    .scaledToFill()
                    .shadow(
                        color: Color.black.opacity(0.8),
                        radius: 6,
                        x: -4,
                        y: 6
                    )
                    .overlay(
                        // Drag handle visualization (for debugging, keep transparent)
                        Color.clear
                            .contentShape(Rectangle())
                            .frame(width: height * handleWidthRatio, height: height * handleHeightRatio)
                            .rotationEffect(.degrees(handleRotation))
                            .offset(x: height * handleOffsetXRatio, y: height * handleOffsetYRatio)
                    )
                    .rotationEffect(
                        .degrees(angle),
                        anchor: UnitPoint(x: rotationAnchorX, y: rotationAnchorY)
                    )
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if isDragging {
                                    onDragging(value: value, geometry: geometry)
                                } else if isInsideDragHandle(location: value.startLocation, geometry: geometry) {
                                    lastDragAngle = calcAngle(location: value.location, geometry: geometry)
                                    isDragging = true
                                }
                            }
                            .onEnded { _ in
                                lastDragAngle = 0
                                isDragging = false
                            }
                    )
            }
        }
        .aspectRatio(692 / 1024.0, contentMode: .fit)
    }

    private func onDragging(value: DragGesture.Value, geometry: GeometryProxy) {
        let currAngle = calcAngle(location: value.location, geometry: geometry)
        let angleChange = normalizeAngle(currAngle - lastDragAngle)
        let progressChange = angleChange / (endAngle - startAngle)
        let currentProgress = playbackProgress < 0 ? 0 : playbackProgress

        playbackProgress = min(1, max(0, currentProgress + progressChange))
        lastDragAngle = currAngle
    }

    private func isInsideDragHandle(location: CGPoint, geometry: GeometryProxy) -> Bool {
        let height = geometry.size.height
        let width = geometry.size.width

        // Handle center position (relative to image center, before tonearm rotation)
        let handleCenterX = width / 2 + height * handleOffsetXRatio
        let handleCenterY = height / 2 + height * handleOffsetYRatio

        // Handle dimensions
        let handleWidth = height * handleWidthRatio
        let handleHeight = height * handleHeightRatio

        // Rotation anchor in pixels
        let anchorX = width * rotationAnchorX
        let anchorY = height * rotationAnchorY

        // Current tonearm angle
        let angle = playbackProgress < 0 ? idleAngle : startAngle + (endAngle - startAngle) * playbackProgress
        let angleRadians = angle * .pi / 180

        // Rotate the handle center around the tonearm anchor
        let dx = handleCenterX - anchorX
        let dy = handleCenterY - anchorY
        let rotatedHandleCenterX = anchorX + dx * cos(angleRadians) - dy * sin(angleRadians)
        let rotatedHandleCenterY = anchorY + dx * sin(angleRadians) + dy * cos(angleRadians)

        // Combined rotation: handle's own rotation + tonearm angle
        let combinedAngle = (handleRotation + angle) * .pi / 180

        // Transform location to handle's local coordinate system
        let localX = location.x - rotatedHandleCenterX
        let localY = location.y - rotatedHandleCenterY

        // Rotate back by the combined angle
        let unrotatedX = localX * cos(-combinedAngle) - localY * sin(-combinedAngle)
        let unrotatedY = localX * sin(-combinedAngle) + localY * cos(-combinedAngle)

        // Check if inside the handle bounds (with tolerance for easier targeting)
        let tolerance = 1.5
        return abs(unrotatedX) <= handleWidth / 2 * tolerance && abs(unrotatedY) <= handleHeight / 2 * tolerance
    }

    private func calcAngle(location: CGPoint, geometry: GeometryProxy) -> Double {
        let anchorX = geometry.size.width * rotationAnchorX
        let anchorY = geometry.size.height * rotationAnchorY
        return atan2(location.y - anchorY, location.x - anchorX) * 180 / Double.pi
    }

    private func normalizeAngle(_ angle: Double) -> Double {
        var normalized = angle
        while normalized > 180 {
            normalized -= 360
        }
        while normalized < -180 {
            normalized += 360
        }
        return normalized
    }
}

#Preview {
    @Previewable @State var progress = 0.0

    TonearmView(
        startAngle: -13,
        endAngle: 13,
        idleAngle: -28,
        playbackProgress: $progress
    )
    .frame(height: 450)
    .padding(56)
}
