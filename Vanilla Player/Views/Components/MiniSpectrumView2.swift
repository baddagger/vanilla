import AppKit
import SwiftUI

// MARK: - GPU-Accelerated Mini Spectrum View

/// An optimized mini spectrum indicator that uses CABasicAnimation for GPU-accelerated
/// bar animations with minimal CPU usage.
struct MiniSpectrumView2: NSViewRepresentable {
    let color: NSColor

    init(color: Color) {
        self.color = NSColor(color)
    }

    func makeNSView(context _: Context) -> MiniSpectrumLayerView {
        let view = MiniSpectrumLayerView(barColor: color)
        return view
    }

    func updateNSView(_: MiniSpectrumLayerView, context _: Context) {
        // Color doesn't change, nothing to update
    }
}

/// NSView that renders animated spectrum bars using CALayers
class MiniSpectrumLayerView: NSView {
    private var barLayers: [CALayer] = []
    private let barColor: NSColor
    private let barCount = 3
    private let barWidth: CGFloat = 3
    private let barSpacing: CGFloat = 3
    private let minHeight: CGFloat = 4
    private let maxHeight: CGFloat = 14

    // Different animation durations for visual variety
    private let durations: [Double] = [0.5, 0.4, 0.6]

    init(barColor: NSColor) {
        self.barColor = barColor
        super.init(frame: .zero)
        wantsLayer = true
        setupBars()
    }

    required init?(coder: NSCoder) {
        barColor = .yellow
        super.init(coder: coder)
        wantsLayer = true
        setupBars()
    }

    private func setupBars() {
        for i in 0 ..< barCount {
            let bar = CALayer()
            bar.backgroundColor = barColor.cgColor
            bar.cornerRadius = 1
            bar.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            layer?.addSublayer(bar)
            barLayers.append(bar)

            // Add animation immediately
            let animation = CABasicAnimation(keyPath: "bounds.size.height")
            animation.fromValue = minHeight
            animation.toValue = maxHeight
            animation.duration = durations[i]
            animation.autoreverses = true
            animation.repeatCount = .infinity
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

            // Offset start time for variety
            animation.beginTime = CACurrentMediaTime() + Double(i) * 0.15
            bar.add(animation, forKey: "heightAnimation")
        }
    }

    override func layout() {
        super.layout()

        let totalWidth = CGFloat(barCount) * barWidth + CGFloat(barCount - 1) * barSpacing
        let startX = (bounds.width - totalWidth) / 2
        let centerY = bounds.height / 2

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        for (index, bar) in barLayers.enumerated() {
            let x = startX + CGFloat(index) * (barWidth + barSpacing) + barWidth / 2
            bar.bounds = CGRect(x: 0, y: 0, width: barWidth, height: minHeight)
            bar.position = CGPoint(x: x, y: centerY)
        }

        CATransaction.commit()
    }
}
