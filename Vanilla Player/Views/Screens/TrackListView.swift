import SwiftUI

struct TrackListView: View {
    @EnvironmentObject var viewModel: PlayerViewModel
    @Environment(\.openWindow) private var openWindow
    @State private var hoveredTrackID: UUID?
    @State private var searchText: String = ""
    @FocusState private var isSearchFocused: Bool
    @State private var isAddMenuVisible: Bool = false

    /// Set to `true` to show clear and remove buttons (disabled since we have source management)
    private let showRemoveFeatures = false

    private var filteredTracks: [Track] {
        if searchText.isEmpty {
            viewModel.tracks
        } else {
            viewModel.tracks.filter { track in
                track.title.localizedCaseInsensitiveContains(searchText)
                    || track.artist.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        let newColor = Color(hex: "#d2af74")

        ZStack {
            VStack {
                // Search bar row
                HStack(spacing: 8) {
                    // Search bar
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(newColor.opacity(0.6))
                            .font(.system(size: 14))
                            .padding(.leading, 6)

                        ZStack(alignment: .leading) {
                            let count = viewModel.tracks.count
                            let format = count == 1 ? NSLocalizedString("Search %d song...", comment: "Search Placeholder Singular") : NSLocalizedString("Search %d songs...", comment: "Search Placeholder Plural")
                            Text(String(format: format, count))
                                .foregroundColor(newColor.opacity(0.5))
                                .font(.system(size: 14, design: .serif))
                                .opacity(searchText.isEmpty ? 1 : 0)

                            TextField("", text: $searchText)
                                .textFieldStyle(.plain)
                                .foregroundColor(newColor)
                                .font(.system(size: 14, design: .serif))
                                .focused($isSearchFocused)
                        }

                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(newColor.opacity(0.6))
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.plain)
                        .opacity(searchText.isEmpty ? 0 : 1)
                        .onHover { isHovering in
                            if isHovering {
                                NSCursor.pointingHand.push()
                            } else {
                                NSCursor.pop()
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.25))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(
                                        newColor.opacity(isSearchFocused ? 0.6 : 0),
                                        lineWidth: 1,
                                    ),
                            ),
                    )
                    .animation(.easeInOut(duration: 0.2), value: isSearchFocused)

                    // More Button
                    MoreMenuButton(
                        isMenuVisible: $isAddMenuVisible,
                        color: newColor,
                        libraryManager: viewModel.libraryManager,
                        onSourceManagement: { openWindow(id: "source-management") },
                    )
                }
                .padding(.horizontal, 32)
                .padding(.top, 8)
                .zIndex(1)

                List {
                    ForEach(filteredTracks) { track in
                        TrackRowView(
                            track: track,
                            isCurrent: viewModel.currentTrack == track,
                            newColor: newColor,
                            hoveredTrackID: $hoveredTrackID,
                            disableHover: isAddMenuVisible,
                            showRemoveButton: showRemoveFeatures,
                            onRemove: {
                                // Disabled: tracks are managed via source management
                            },
                            onPlay: {
                                if let index = viewModel.tracks.firstIndex(
                                    of: track,
                                ) {
                                    viewModel.playTrack(at: index)
                                }
                            },
                        )
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .padding([.leading, .trailing, .bottom], 24)
            }
        }
    }
}

struct MiniSpectrumView: View {
    let color: Color

    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            SpectrumBar(color: color, duration: 0.5)
            SpectrumBar(color: color, duration: 0.4)
            SpectrumBar(color: color, duration: 0.6)
        }
        .frame(height: 16)
    }
}

struct SpectrumBar: View {
    let color: Color
    let duration: Double
    @State private var height: CGFloat = 4

    var body: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(color)
            .frame(width: 3, height: height)
            .onAppear {
                height = 14
            }
            .animation(
                .easeInOut(duration: duration)
                    .repeatForever(autoreverses: true),
                value: height,
            )
    }
}

struct TrackRowView: View {
    let track: Track
    let isCurrent: Bool
    let newColor: Color
    @Binding var hoveredTrackID: UUID?
    let disableHover: Bool
    let showRemoveButton: Bool
    let onRemove: () -> Void
    let onPlay: () -> Void
    @EnvironmentObject var viewModel: PlayerViewModel

    var body: some View {
        let isHovered = !disableHover && hoveredTrackID == track.id

        HStack {
            ArtworkView(track: track)
                .frame(width: 32, height: 32)
                .cornerRadius(4)
                .padding(.trailing, 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .foregroundColor(
                        isCurrent ? newColor : .white,
                    )
                    .font(.system(size: 14, design: .serif))

                if !track.artist.isEmpty {
                    Text(track.artist)
                        .foregroundColor(
                            isCurrent
                                ? newColor.opacity(0.8) : .white.opacity(0.6),
                        )
                        .font(.system(size: 12, design: .serif))
                }
            }

            if isCurrent, viewModel.isPlaying {
                Spacer()
                MiniSpectrumView(color: newColor)
            } else {
                Spacer()
            }

            if showRemoveButton, hoveredTrackID == track.id {
                RemoveButton(color: newColor, action: onRemove)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isHovered ? Color.white.opacity(0.05) : Color.clear)
        .cornerRadius(6)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .contentShape(Rectangle())
        .onTapGesture(perform: onPlay)
        .onHover { isHovering in
            if !disableHover {
                hoveredTrackID = isHovering ? track.id : nil
            }
            if isHovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .overlay(
            VStack {
                Spacer()
                if isCurrent {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    .clear, newColor, .clear,
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing,
                            ),
                        )
                        .frame(height: 1)
                        .opacity(0.6)
                }
            },
        )
    }
}

struct ArtworkView: View {
    let track: Track?
    @State private var artwork: NSImage?

    var body: some View {
        ZStack {
            if let artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                // Placeholder
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                Image(systemName: "music.note")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.3))
            }
        }
        .onAppear {
            loadArtwork(for: track)
        }
        .onChange(of: track) { newTrack in
            loadArtwork(for: newTrack)
        }
    }

    private func loadArtwork(for track: Track?) {
        artwork = nil
        guard let track else { return }

        if !track.hasArtwork {
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let loaded = track.loadArtwork()
            DispatchQueue.main.async {
                artwork = loaded
            }
        }
    }
}

struct RemoveButton: View {
    let color: Color
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(color)
                    .opacity(isHovering ? 1.0 : 0.8)

                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.black.opacity(0.8))
            }
            .frame(width: 16, height: 16)
            .scaleEffect(isHovering ? 1.1 : 1.0)
            .animation(
                .spring(response: 0.3, dampingFraction: 0.7),
                value: isHovering,
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - More Menu Button

struct MoreMenuButton: View {
    @Binding var isMenuVisible: Bool
    let color: Color
    @ObservedObject var libraryManager: LibraryManager
    let onSourceManagement: () -> Void

    @State private var isHovering = false

    var body: some View {
        // More Button
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isMenuVisible.toggle()
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(isHovering ? color : color.opacity(0.6))
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(color.opacity(isHovering ? 0.15 : 0)),
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .rotationEffect(.degrees(90))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .overlay {
            if isMenuVisible {
                // Full-screen dismiss layer
                Color.black.opacity(0.001)
                    .frame(width: 10000, height: 10000)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isMenuVisible = false
                        }
                    }
            }
        }
        .overlay(alignment: .topTrailing) {
            if isMenuVisible {
                VStack(alignment: .leading, spacing: 0) {
                    MenuItem(
                        icon: "doc.badge.plus",
                        title: NSLocalizedString("Add Song", comment: "Menu Item"),
                        color: color,
                    ) {
                        addFile()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isMenuVisible = false
                        }
                    }

                    Divider()
                        .background(color.opacity(0.2))

                    MenuItem(
                        icon: "folder.badge.plus",
                        title: NSLocalizedString("Add Folder", comment: "Menu Item"),
                        color: color,
                    ) {
                        addFolder()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isMenuVisible = false
                        }
                    }

                    Divider()
                        .background(color.opacity(0.2))

                    MenuItem(
                        icon: "arrow.clockwise",
                        title: NSLocalizedString("Rescan", comment: "Menu Item"),
                        color: color,
                    ) {
                        libraryManager.startFullScan()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isMenuVisible = false
                        }
                    }

                    Divider()
                        .background(color.opacity(0.2))

                    MenuItem(
                        icon: "gearshape",
                        title: NSLocalizedString("Source Management", comment: "Menu Item"),
                        color: color,
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isMenuVisible = false
                        }
                        onSourceManagement()
                    }
                }
                .fixedSize()
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.85))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(color.opacity(0.3), lineWidth: 1),
                        )
                        .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 4),
                )
                .cornerRadius(12)
                .offset(x: 8, y: 40)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.8, anchor: .topTrailing)
                        .combined(with: .opacity),
                    removal: .scale(scale: 0.8, anchor: .topTrailing)
                        .combined(with: .opacity),
                ))
            }
        }
    }

    private func addFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = NSLocalizedString("Add Source", comment: "Panel Button")

        if panel.runModal() == .OK {
            let urls = panel.urls
            Task {
                for url in urls {
                    await libraryManager.addSource(url: url)
                }
            }
        }
    }

    private func addFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.audio]
        panel.prompt = NSLocalizedString("Add Song", comment: "Panel Button")

        if panel.runModal() == .OK {
            let urls = panel.urls
            Task {
                for url in urls {
                    await libraryManager.addSource(url: url)
                }
            }
        }
    }
}

struct MenuItem: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)
                    .frame(width: 20)

                Text(title)
                    .font(.system(size: 14, design: .serif))
                    .foregroundColor(color)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Rectangle()
                    .fill(isHovering ? color.opacity(0.15) : Color.clear),
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

#Preview {
    TrackListView()
        .environmentObject(PlayerViewModel())
        .background(Color.gray)
        .padding()
}
