import AppKit
import Combine
import SwiftUI

// MARK: - Optimized Segmented Spectrum View

/// A high-performance segmented bar spectrum visualizer.
/// Uses a static grid mask and frame-based animations for maximum smoothness.
struct SpectrumView3: NSViewRepresentable {
    @ObservedObject var viewModel: VisualizerViewModel

    func makeNSView(context _: Context) -> SpectrumLayerView3 {
        let view = SpectrumLayerView3()
        return view
    }

    func updateNSView(_ nsView: SpectrumLayerView3, context _: Context) {
        nsView.updateLevels(viewModel.meteringLevels)
    }
}

/// NSView that renders segmented spectrum bars using optimized CALayers
class SpectrumLayerView3: NSView {
    private var activeBarLayers: [CAGradientLayer] = []
    private var backgroundBarLayers: [CAGradientLayer] = []
    private let containerLayer = CALayer()
    private let maskLayer = CALayer()
    private var isSetup = false

    // Segment configuration
    private let segmentHeight: CGFloat = 3.0
    private let segmentSpacing: CGFloat = 1.5
    private let barCount = 32
    private let barSpacing: CGFloat = 2.0

    // Design Colors: Custom Gold Palette (Dark at bottom, Light at top)
    private let gradientColors: [CGColor] = [
        NSColor(hex: "#be9748")?.cgColor ?? NSColor.yellow.cgColor, // dark gold (bottom)
        NSColor(hex: "#efc86c")?.cgColor ?? NSColor.orange.cgColor, // gold
        NSColor(hex: "#ffd188")?.cgColor ?? NSColor.brown.cgColor, // light gold (top)
    ]

    private let gradientLocations: [NSNumber] = [0.0, 0.5, 1.0]

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        setupLayers()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        setupLayers()
    }

    private func setupLayers() {
        layer?.addSublayer(containerLayer)
        containerLayer.mask = maskLayer
    }

    override func layout() {
        super.layout()
        setupBarsIfNeeded()
        layoutBarsAndMask()
    }

    private func setupBarsIfNeeded() {
        guard !isSetup, bounds.width > 0 else { return }
        isSetup = true

        for _ in 0 ..< barCount {
            // Background bar (static grid)
            let bgBar = CAGradientLayer()
            bgBar.colors = gradientColors
            bgBar.locations = gradientLocations
            bgBar.opacity = 0.1 // Faded background
            containerLayer.addSublayer(bgBar)
            backgroundBarLayers.append(bgBar)

            // Active bar (dynamic height)
            let activeBar = CAGradientLayer()
            activeBar.colors = gradientColors
            activeBar.locations = gradientLocations

            // Glow effect
            activeBar.shadowColor = NSColor(hex: "#efc86c")?.cgColor
            activeBar.shadowOffset = .zero
            activeBar.shadowRadius = 4.0
            activeBar.shadowOpacity = 0.6

            containerLayer.addSublayer(activeBar)
            activeBarLayers.append(activeBar)
        }
    }

    private func layoutBarsAndMask() {
        guard isSetup else { return }

        containerLayer.frame = bounds
        maskLayer.frame = bounds
        maskLayer.sublayers?.forEach { $0.removeFromSuperlayer() }

        let totalWidth = bounds.width
        let effectiveBarWidth = totalWidth / CGFloat(barCount)
        let actualBarWidth = effectiveBarWidth * 0.8
        let actualSpacing = effectiveBarWidth * 0.2

        let totalSegmentHeight = segmentHeight + segmentSpacing
        let numberOfSegments = Int(bounds.height / totalSegmentHeight)
        let occupiedHeight = CGFloat(numberOfSegments) * totalSegmentHeight - segmentSpacing
        let yOffset = (bounds.height - occupiedHeight) / 2

        for index in 0 ..< barCount {
            let x = CGFloat(index) * (actualBarWidth + actualSpacing)

            // Background bars as baseline (lowest segment only)
            backgroundBarLayers[index].frame = CGRect(
                x: x,
                y: yOffset,
                width: actualBarWidth,
                height: segmentHeight,
            )

            // Active bars grow from the bottom
            activeBarLayers[index].frame = CGRect(
                x: x,
                y: yOffset,
                width: actualBarWidth,
                height: 0,
            )

            // Add segments to the mask for this bar
            for s in 0 ..< numberOfSegments {
                let segment = CALayer()
                segment.backgroundColor = NSColor.white.cgColor
                segment.frame = CGRect(
                    x: x,
                    y: yOffset + CGFloat(s) * totalSegmentHeight,
                    width: actualBarWidth,
                    height: segmentHeight,
                )
                maskLayer.addSublayer(segment)
            }
        }
    }

    func updateLevels(_ levels: [Float]) {
        guard activeBarLayers.count == levels.count else { return }

        CATransaction.begin()
        CATransaction.setAnimationDuration(0.04) // Same as SpectrumView2 for smoothness
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .linear))

        let totalSegmentHeight = segmentHeight + segmentSpacing
        let numberOfSegments = Int(bounds.height / totalSegmentHeight)
        let occupiedHeight = CGFloat(numberOfSegments) * totalSegmentHeight - segmentSpacing
        let yOffset = (bounds.height - occupiedHeight) / 2

        for (index, bar) in activeBarLayers.enumerated() {
            let level = CGFloat(levels[index])
            let targetHeight = occupiedHeight * level

            let x = bar.frame.origin.x
            let width = bar.frame.size.width

            // Grow bottom-up: Origin stays at yOffset
            bar.frame = CGRect(
                x: x,
                y: yOffset,
                width: width,
                height: targetHeight,
            )
        }

        CATransaction.commit()
    }
}

// MARK: - NSColor Hex Extension

private extension NSColor {
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}

#Preview {
    let mockAudio = AudioEngineManager()
    let mockVM = VisualizerViewModel(audioManager: mockAudio)
    SpectrumView3(viewModel: mockVM)
        .frame(width: 400, height: 100)
        .padding()
        .background(Color.black)
}
