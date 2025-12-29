import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct TrackInfoView: View {
    @EnvironmentObject var playerViewModel: PlayerViewModel
    @StateObject private var viewModel: TagsEditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    @State private var isHoveringArtwork = false

    init(track: Track) {
        _viewModel = StateObject(wrappedValue: TagsEditorViewModel(track: track))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with Artwork and Basic Info
            HStack(spacing: 20) {
                // Interactive Artwork
                ZStack {
                    if let artwork = viewModel.artwork {
                        Image(nsImage: artwork)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        ZStack {
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.primary.opacity(0.12),
                                    Color.primary.opacity(0.06),
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing,
                            )
                            Image(systemName: "music.note")
                                .font(.system(size: 32, weight: .semibold))
                                .foregroundColor(.primary.opacity(0.4))
                        }
                    }

                    // Hover Overlays
                    if isHoveringArtwork {
                        ZStack {
                            Color.black.opacity(0.4)

                            HStack(spacing: 12) {
                                if viewModel.artworkChanged {
                                    // Reset Button
                                    ArtworkActionButton(
                                        systemName: "arrow.uturn.backward.circle.fill",
                                        help: "Reset to original artwork",
                                    ) {
                                        viewModel.resetArtwork()
                                    }
                                } else {
                                    // Select Button
                                    ArtworkActionButton(
                                        systemName: "plus.circle.fill",
                                        help: "Select new artwork",
                                    ) {
                                        selectArtwork()
                                    }
                                }

                                if viewModel.artwork != nil {
                                    // Delete Button
                                    ArtworkActionButton(
                                        systemName: "trash.circle.fill",
                                        help: "Remove artwork",
                                    ) {
                                        viewModel.deleteArtwork()
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(width: 80, height: 80)
                .cornerRadius(8)
                .shadow(radius: 4)
                .onHover { isHoveringArtwork = $0 }
                .onDrop(of: [.image], isTargeted: nil) { providers in
                    handleDrop(providers: providers)
                }
                .onTapGesture {
                    selectArtwork()
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.title.isEmpty ? viewModel.track.title : viewModel.title)
                        .font(.headline)
                        .lineLimit(1)
                    Text(viewModel.artist.isEmpty ? viewModel.track.artist : viewModel.artist)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    Text(viewModel.album.isEmpty ? viewModel.track.album : viewModel.album)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding()
            .background(Color.primary.opacity(0.05))

            Picker("", selection: $selectedTab) {
                Text(NSLocalizedString("DETAILS", comment: "")).tag(0)
                Text(NSLocalizedString("FILE_INFO", comment: "")).tag(1)
            }
            .pickerStyle(.segmented)
            .padding()

            Divider()

            ScrollView {
                if selectedTab == 0 {
                    detailsTab
                } else {
                    fileInfoTab
                }
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
            }

            Divider()

            HStack {
                Spacer()
                Button(NSLocalizedString("SAVE", comment: "Button")) {
                    viewModel.save()
                    if viewModel.isSaved {
                        Task {
                            await playerViewModel.libraryManager.refreshTrack(viewModel.track)
                        }
                        dismiss()
                    }
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(viewModel.isLoading || !viewModel.hasChanges)
                .padding()
            }
        }
        .navigationTitle(NSLocalizedString("TRACK_DETAILS", comment: "Navigation Title"))
        .frame(minWidth: 450, minHeight: 500)
    }

    private var detailsTab: some View {
        Grid(alignment: .trailing, horizontalSpacing: 15, verticalSpacing: 12) {
            GridRow {
                Text(NSLocalizedString("TITLE", comment: "Label"))
                TextField("", text: $viewModel.title)
                    .textFieldStyle(.roundedBorder)
            }
            GridRow {
                Text(NSLocalizedString("ARTIST", comment: "Label"))
                TextField("", text: $viewModel.artist)
                    .textFieldStyle(.roundedBorder)
            }
            GridRow {
                Text(NSLocalizedString("ALBUM", comment: "Label"))
                TextField("", text: $viewModel.album)
                    .textFieldStyle(.roundedBorder)
            }

            Divider()

            GridRow {
                Text(NSLocalizedString("TRACK_NUMBER", comment: "Label"))
                TextField("", text: $viewModel.trackNumber)
                    .textFieldStyle(.roundedBorder)
            }
            GridRow {
                Text(NSLocalizedString("YEAR", comment: "Label"))
                TextField("", text: $viewModel.year)
                    .textFieldStyle(.roundedBorder)
            }
            GridRow {
                Text(NSLocalizedString("GENRE", comment: "Label"))
                TextField("", text: $viewModel.genre)
                    .textFieldStyle(.roundedBorder)
            }

            Divider()

            GridRow {
                Text(NSLocalizedString("COMMENT", comment: "Label"))
                TextField("", text: $viewModel.comment, axis: .vertical)
                    .lineLimit(3 ... 6)
                    .textFieldStyle(.roundedBorder)
            }
        }
        .padding()
    }

    private var fileInfoTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            InfoRow(
                label: NSLocalizedString("FILE_PATH", comment: ""),
                value: viewModel.track.url.path,
            )
            InfoRow(
                label: NSLocalizedString("FILE_SIZE", comment: ""),
                value: formatBytes(viewModel.fileSize),
            )
            InfoRow(
                label: NSLocalizedString("FILE_FORMAT", comment: ""),
                value: viewModel.fileFormat,
            )
            InfoRow(
                label: NSLocalizedString("FILE_DURATION", comment: ""),
                value: formatDuration(viewModel.duration),
            )
            InfoRow(
                label: NSLocalizedString("FILE_BITRATE", comment: ""),
                value: "\(viewModel.bitrate) kbps",
            )
            if viewModel.bitDepth > 0 {
                InfoRow(
                    label: NSLocalizedString("FILE_BITDEPTH", comment: ""),
                    value: "\(viewModel.bitDepth) bit",
                )
            }
            InfoRow(
                label: NSLocalizedString("FILE_SAMPLERATE", comment: ""),
                value: "\(Int(viewModel.sampleRate)) Hz",
            )
        }
        .padding()
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private func formatDuration(_ seconds: Int) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: TimeInterval(seconds)) ?? "0:00"
    }

    private func selectArtwork() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.image]
        panel.begin { response in
            if response == .OK, let url = panel.url {
                if let image = NSImage(contentsOf: url) {
                    viewModel.setArtwork(image)
                }
            }
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadObject(ofClass: NSImage.self) { item, _ in
            if let image = item as? NSImage {
                DispatchQueue.main.async {
                    viewModel.setArtwork(image)
                }
            }
        }
        return true
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
        }
    }
}

struct ArtworkActionButton: View {
    let systemName: String
    let help: String
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 22))
                .foregroundColor(.white)
                .scaleEffect(isHovering ? 1.15 : 1.0)
                .brightness(isHovering ? 0.1 : 0)
                .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isHovering)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help(help)
    }
}
