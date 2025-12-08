import AppKit
import SwiftUI

// MARK: - GPU-Accelerated Rotating Cover

/// A rotating vinyl cover that uses CABasicAnimation for GPU-accelerated rotation
/// with virtually zero CPU usage.
struct RotatingVinylCover: NSViewRepresentable {
    let track: Track?
    let isSpinning: Bool
    let rpm: Double // Revolutions per minute

    func makeNSView(context _: Context) -> RotatingImageView {
        let view = RotatingImageView()
        view.rpm = rpm
        return view
    }

    func updateNSView(_ nsView: RotatingImageView, context _: Context) {
        nsView.rpm = rpm

        // Update spinning state
        if isSpinning {
            nsView.startSpinning()
        } else {
            nsView.stopSpinning()
        }

        // Update artwork if track changed
        if nsView.currentTrack?.url != track?.url {
            nsView.currentTrack = track
            nsView.updateArtwork(for: track)
        }
    }
}

/// NSView that performs GPU-accelerated rotation using CABasicAnimation
class RotatingImageView: NSView {
    private let imageLayer = CALayer()
    private var currentRotation: CGFloat = 0
    private var animationStartTime: CFTimeInterval = 0
    var currentTrack: Track?
    var rpm: Double = 2.5

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupLayer()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayer()
    }

    private func setupLayer() {
        wantsLayer = true
        layer?.addSublayer(imageLayer)
        imageLayer.contentsGravity = .resizeAspectFill
        imageLayer.masksToBounds = true
        imageLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        // Position the layer at center with proper anchor point
        imageLayer.bounds = CGRect(origin: .zero, size: bounds.size)
        imageLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        imageLayer.cornerRadius = bounds.width / 2
        CATransaction.commit()
    }

    func updateArtwork(for track: Track?) {
        guard let track, track.hasArtwork else {
            imageLayer.contents = nil
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let artwork = track.loadArtwork()
            DispatchQueue.main.async {
                self?.imageLayer.contents = artwork
            }
        }
    }

    func startSpinning() {
        guard imageLayer.animation(forKey: "rotation") == nil else { return }

        // Calculate starting angle from where we left off
        let animation = CABasicAnimation(keyPath: "transform.rotation.z")
        animation.fromValue = currentRotation
        animation.toValue = currentRotation + CGFloat.pi * 2
        animation.duration = 60.0 / rpm // Duration for one full rotation
        animation.repeatCount = .infinity
        animation.isRemovedOnCompletion = false

        animationStartTime = CACurrentMediaTime()
        imageLayer.add(animation, forKey: "rotation")
    }

    func stopSpinning() {
        guard let presentation = imageLayer.presentation(),
              imageLayer.animation(forKey: "rotation") != nil
        else { return }

        // Capture current rotation angle
        if let transform = presentation.value(forKeyPath: "transform.rotation.z") as? CGFloat {
            currentRotation = transform.truncatingRemainder(dividingBy: CGFloat.pi * 2)
        }

        // Remove animation and set static rotation
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        imageLayer.removeAnimation(forKey: "rotation")
        imageLayer.transform = CATransform3DMakeRotation(currentRotation, 0, 0, 1)
        CATransaction.commit()
    }
}
