import SwiftUI

struct DigitalNowPlayingView: View {
    @EnvironmentObject var viewModel: PlayerViewModel
    @AppStorage("spectrumStyle") private var spectrumStyle: SettingsView.SpectrumStyle = .bars

    var body: some View {
        VStack(alignment: .center) {
            Spacer()

            SquareCoverView(track: viewModel.currentTrack)

            Spacer()
                .frame(height: 56)

            let textColor = Color(hex: "#c0a06c")

            Text(viewModel.currentTrack?.title ?? NSLocalizedString(
                "Ready to Play",
                comment: "Placeholder Title",
            ))
            .font(.system(size: 36, weight: .light, design: .serif))
            .foregroundColor(textColor)
            .multilineTextAlignment(.center)
            .lineLimit(3)
            .padding(.horizontal, 12)

            if let artist = viewModel.currentTrack?.artist, !artist.isEmpty {
                Spacer().frame(height: 8)

                Text(artist)
                    .font(.system(size: 18, weight: .light, design: .serif))
                    .foregroundColor(textColor)
                    .lineLimit(1)
                    .padding(.horizontal, 12)
            }

            if let album = viewModel.currentTrack?.album, !album.isEmpty {
                Spacer().frame(height: 8)

                Text(album)
                    .font(.system(size: 14, weight: .light, design: .serif))
                    .foregroundColor(textColor.opacity(0.8))
                    .lineLimit(1)
                    .padding(.horizontal, 12)
            }

            Spacer()

            if spectrumStyle == .segmentedBars {
                SpectrumView3(viewModel: viewModel.visualizerViewModel)
                    .frame(height: 80)
                    .padding(.horizontal, 24)
            } else {
                SpectrumView2(viewModel: viewModel.visualizerViewModel)
                    .frame(height: 80)
                    .padding(.horizontal, 24)
            }

            PlaybackSliderView(
                currentTime: $viewModel.currentTime,
                duration: viewModel.duration,
                onSeek: { newTime in
                    viewModel.seek(to: newTime)
                },
            )
            .padding(24)
        }
    }

    func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct SquareCoverView: View {
    let track: Track?
    @State private var artwork: NSImage?

    var body: some View {
        ZStack {
            if let artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 200, height: 200)
                    .clipped()
            } else {
                // Placeholder for cover art
                Image(systemName: "music.note")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .foregroundColor(Color(hex: "#c0a06c").opacity(0.5))
            }
        }
        .frame(width: 200, height: 200)
        .background(Color.white.opacity(0.12))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1),
        )
        .onChange(of: track) { newTrack in
            loadArtwork(for: newTrack)
        }
        .onAppear {
            loadArtwork(for: track)
        }
    }

    private func loadArtwork(for track: Track?) {
        artwork = nil // Reset first
        guard let track else { return }

        if !track.hasArtwork {
            // print("Track \(track.title) has no artwork marked.")
            return
        }

        // Async load
        DispatchQueue.global(qos: .userInitiated).async {
            let loaded = track.loadArtwork()
            DispatchQueue.main.async {
                // print("Loaded artwork for \(track.title): \(loaded != nil)")
                artwork = loaded
            }
        }
    }
}
