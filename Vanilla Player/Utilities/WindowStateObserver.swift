import SwiftUI

struct WindowStateObserver: NSViewRepresentable {
    var onWindowStateChange: (Bool) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.setupObservation(for: view)
        return view
    }

    func updateNSView(_: NSView, context _: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onWindowStateChange: onWindowStateChange)
    }

    class Coordinator: NSObject {
        var onWindowStateChange: (Bool) -> Void
        private var window: NSWindow?

        init(onWindowStateChange: @escaping (Bool) -> Void) {
            self.onWindowStateChange = onWindowStateChange
        }

        func setupObservation(for view: NSView) {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if let window = view.window {
                    self.window = window
                    startObserving(window: window)
                }
            }
        }

        private func startObserving(window: NSWindow) {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowDidMiniaturize),
                name: NSWindow.willMiniaturizeNotification,
                object: window,
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowDidDeminiaturize),
                name: NSWindow.didDeminiaturizeNotification,
                object: window,
            )

            // Initial state check
            onWindowStateChange(window.isMiniaturized)
        }

        @objc private func windowDidMiniaturize() {
            onWindowStateChange(true)
        }

        @objc private func windowDidDeminiaturize() {
            onWindowStateChange(false)
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }
    }
}
