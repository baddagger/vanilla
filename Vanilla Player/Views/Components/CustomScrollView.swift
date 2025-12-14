import AppKit
import SwiftUI

struct CustomScrollView<Content: View>: View {
    let content: Content

    // Custom Scrollbar State
    @State private var contentOffset: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var frameHeight: CGFloat = 0
    @State private var nsScrollView: NSScrollView?
    @State private var isDragging: Bool = false
    @State private var dragStartContentOffset: CGFloat = 0
    @State private var isHovered: Bool = false

    // Custom Scrollbar Formatting
    let thumbColor: Color = .white.opacity(0.1)
    let thumbColorHovered: Color = .white.opacity(0.2)
    let trackColor: Color = .white.opacity(0)
    let thumbWidth: CGFloat = 6

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView {
            content
                .background(
                    GeometryReader { geo -> Color in
                        DispatchQueue.main.async {
                            contentHeight = geo.size.height
                            contentOffset = -geo.frame(in: .named("scroll")).minY
                        }
                        return Color.clear
                    },
                )
                .background(ScrollAccessor(nsScrollView: $nsScrollView))
        }
        .coordinateSpace(name: "scroll")
        .scrollIndicators(.never)
        .scrollContentBackground(.hidden)
        .padding(.trailing, thumbWidth + 4) // Always reserve space to prevent layout flicker
        .background(
            GeometryReader { geo -> Color in
                DispatchQueue.main.async {
                    frameHeight = geo.size.height
                }
                return Color.clear
            },
        )

        .overlay(alignment: .trailing) {
            if contentHeight > frameHeight {
                ZStack(alignment: .top) {
                    // Track
                    Capsule()
                        .fill(trackColor)
                        .frame(width: thumbWidth)
                        .padding(.vertical, 4)

                    // Thumb
                    Capsule()
                        .fill((isHovered || isDragging) ? thumbColorHovered : thumbColor)
                        .frame(width: thumbWidth, height: thumbHeight())
                        .offset(y: thumbOffset())
                        .padding(.vertical, 4)
                        .onHover { hovered in
                            isHovered = hovered
                        }
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    guard let scrollView = nsScrollView else { return }

                                    // Capture initial state
                                    if !isDragging {
                                        isDragging = true
                                        dragStartContentOffset = contentOffset
                                    }

                                    let totalContentHeight = contentHeight - frameHeight
                                    let scrollableTrackHeight = frameHeight - thumbHeight()

                                    guard totalContentHeight > 0,
                                          scrollableTrackHeight > 0 else { return }

                                    // Calculate delta
                                    let deltaY = value.translation.height
                                    let deltaProgress = deltaY / scrollableTrackHeight
                                    let deltaContentOffset = deltaProgress * totalContentHeight

                                    // Apply new offset
                                    let newOffset = min(
                                        max(0, dragStartContentOffset + deltaContentOffset),
                                        totalContentHeight,
                                    )

                                    // Update NSScrollView directly
                                    // Since coordinate system of NSScrollView documentView is
                                    // flipped or not?
                                    // In standard SwiftUI/NSScrollView, Y increases downwards
                                    // usually for document view scrolling?
                                    // Actually NSScrollView uses bounds.origin.
                                    // For vertical scrolling, usually y starts at 0 at top (if
                                    // flipped) or bottom (if not).
                                    // SwiftUI is usually Flipped (Top-Left 0,0).

                                    if let documentView = scrollView.documentView {
                                        let point = NSPoint(x: 0, y: newOffset)
                                        documentView.scroll(point)
                                        // Force immediate update?
                                        // scrollView.contentView.bounds.origin = point
                                    }
                                }
                                .onEnded { _ in
                                    isDragging = false
                                },
                        )
                }
                .frame(width: thumbWidth)
                .frame(height: frameHeight)
                .padding(.trailing, 2)
                .padding(.bottom, 4)
            }
        }
    }

    // Calculate thumb height based on content ratio
    private func thumbHeight() -> CGFloat {
        guard contentHeight > 0 else { return 30 }
        let ratio = frameHeight / contentHeight
        let height = frameHeight * ratio
        return max(height, 30) // Minimum thumb size
    }

    // Calculate thumb position
    private func thumbOffset() -> CGFloat {
        guard (contentHeight - frameHeight) > 0 else { return 0 }
        let progress = contentOffset / (contentHeight - frameHeight)
        let scrollableHeight = frameHeight - thumbHeight()
        return progress * scrollableHeight
    }
}

struct ScrollAccessor: NSViewRepresentable {
    @Binding var nsScrollView: NSScrollView?

    func makeNSView(context _: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            nsScrollView = view.enclosingScrollView
        }
        return view
    }

    func updateNSView(_: NSView, context _: Context) {}
}
