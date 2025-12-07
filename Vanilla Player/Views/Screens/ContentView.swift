import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: PlayerViewModel
    
    var body: some View {
        ZStack {
            Image("woodBackground")
                .resizable()
                .clipped()
                .ignoresSafeArea()
                .overlay(
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.05),
                                    Color.white.opacity(0.02),
                                    Color.white.opacity(0),
                                    Color.white.opacity(0),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .ignoresSafeArea()
                )

            HStack {
                VinylNowPlayingView()
                Spacer()
                    .frame(width: 260)

                DigitalPlayerView()
            }
            .padding(.top, 24)
            .padding([.leading, .trailing, .bottom], 32)
        }
        .background(SpacebarHandler(onSpacebar: {
            viewModel.playPause()
        }))
        .background(WindowStateObserver(onWindowStateChange: { isMiniaturized in
            viewModel.setWindowVisible(!isMiniaturized)
        }))
    }
}

/// NSViewRepresentable that listens for spacebar key events without affecting focus
struct SpacebarHandler: NSViewRepresentable {
    let onSpacebar: () -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = KeyHandlerView()
        view.onSpacebar = onSpacebar
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? KeyHandlerView)?.onSpacebar = onSpacebar
    }
    
    class KeyHandlerView: NSView {
        var onSpacebar: (() -> Void)?
        private var monitor: Any?
        
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window != nil && monitor == nil {
                monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                    // Check if spacebar (keyCode 49) and no text field is focused
                    if event.keyCode == 49 {
                        if let firstResponder = event.window?.firstResponder,
                           firstResponder is NSTextView || firstResponder is NSTextField {
                            // Let text fields handle the space
                            return event
                        }
                        self?.onSpacebar?()
                        return nil // Consume the event
                    }
                    return event
                }
            }
        }
        
        deinit {
            if let monitor = monitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(PlayerViewModel())
}
