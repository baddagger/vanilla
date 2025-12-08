import AppKit
import Combine
import SwiftUI

// MARK: - GPU-Accelerated Spectrum View

/// An optimized spectrum visualizer that uses CALayer for GPU-accelerated rendering
/// with minimal CPU usage. Uses Core Animation implicit animations for smooth bar movement.
struct SpectrumView2: NSViewRepresentable {
    @ObservedObject var viewModel: VisualizerViewModel

    func makeNSView(context _: Context) -> SpectrumLayerView {
        let view = SpectrumLayerView()
        return view
    }

    func updateNSView(_ nsView: SpectrumLayerView, context _: Context) {
        nsView.updateLevels(viewModel.meteringLevels)
    }
}

/// NSView that renders spectrum bars using CALayers for GPU-accelerated drawing
class SpectrumLayerView: NSView {
    private var barLayers: [CAGradientLayer] = []
    private var isSetup = false

    // Colors matching the original gradient
    private let gradientColors: [CGColor] = [
        NSColor(hex: "#dbbe83")?.cgColor ?? NSColor.yellow.cgColor,
        NSColor(hex: "#d8b86c")?.cgColor ?? NSColor.orange.cgColor,
        NSColor(hex: "#af905d")?.cgColor ?? NSColor.brown.cgColor,
        NSColor(hex: "#d8b86c")?.cgColor ?? NSColor.orange.cgColor,
        NSColor(hex: "#dbbe83")?.cgColor ?? NSColor.yellow.cgColor,
    ]

    private let gradientLocations: [NSNumber] = [0.0, 0.15, 0.5, 0.85, 1.0]

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer?.masksToBounds = true
    }

    override func layout() {
        super.layout()
        setupBarsIfNeeded()
        layoutBars()
    }

    private func setupBarsIfNeeded() {
        guard !isSetup, bounds.width > 0 else { return }
        isSetup = true

        // Create 32 bar layers
        let barCount = 32
        for _ in 0 ..< barCount {
            let bar = CAGradientLayer()
            bar.colors = gradientColors
            bar.locations = gradientLocations
            bar.startPoint = CGPoint(x: 0.5, y: 0)
            bar.endPoint = CGPoint(x: 0.5, y: 1)
            bar.cornerRadius = 1.3
            bar.masksToBounds = true

            layer?.addSublayer(bar)
            barLayers.append(bar)
        }
    }

    private func layoutBars() {
        guard !barLayers.isEmpty else { return }

        let barCount = barLayers.count
        let totalSpacing = bounds.width
        let barWidth: CGFloat = 2.6
        let spacing = (totalSpacing - CGFloat(barCount) * barWidth) / CGFloat(barCount - 1)

        for (index, bar) in barLayers.enumerated() {
            let x = CGFloat(index) * (barWidth + spacing)
            // Initial minimum height
            let minHeight: CGFloat = 6
            bar.frame = CGRect(
                x: x,
                y: (bounds.height - minHeight) / 2,
                width: barWidth,
                height: minHeight,
            )
        }
    }

    func updateLevels(_ levels: [Float]) {
        guard barLayers.count == levels.count else { return }

        // Configure implicit animation duration
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.04)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .linear))

        let barCount = barLayers.count
        let totalSpacing = bounds.width
        let barWidth: CGFloat = 2.6
        let spacing = (totalSpacing - CGFloat(barCount) * barWidth) / CGFloat(barCount - 1)

        for (index, bar) in barLayers.enumerated() {
            let level = CGFloat(levels[index])
            let barHeight = max(6, bounds.height * level)
            let x = CGFloat(index) * (barWidth + spacing)
            let y = (bounds.height - barHeight) / 2

            bar.frame = CGRect(x: x, y: y, width: barWidth, height: barHeight)
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
    SpectrumView2(viewModel: mockVM)
        .frame(height: 50)
        .padding()
        .background(Color.black)
}
