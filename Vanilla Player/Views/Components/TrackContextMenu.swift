import SwiftUI

struct TrackContextMenuModifier: ViewModifier {
    let track: Track?
    @EnvironmentObject var viewModel: PlayerViewModel
    @Environment(\.openWindow) private var openWindow

    func body(content: Content) -> some View {
        content.contextMenu {
            if let track {
                Button {
                    openWindow(id: "track-info", value: track)
                } label: {
                    Label(
                        NSLocalizedString("TRACK_DETAILS", comment: "Context Menu"),
                        systemImage: "info.circle",
                    )
                }

                Divider()

                Button {
                    if let url = track.resolvedURL() ?? Optional(track.url) {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }
                } label: {
                    Label(
                        NSLocalizedString("SHOW_IN_FINDER", comment: "Context Menu"),
                        systemImage: "folder",
                    )
                }
            }
        }
    }
}

extension View {
    func trackContextMenu(for track: Track?) -> some View {
        modifier(TrackContextMenuModifier(track: track))
    }
}
