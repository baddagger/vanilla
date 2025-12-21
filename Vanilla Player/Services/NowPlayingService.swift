import Foundation
import MediaPlayer

class NowPlayingService {
    typealias CommandHandler = () -> Void
    typealias SeekHandler = (TimeInterval) -> Void

    private var playHandler: CommandHandler?
    private var pauseHandler: CommandHandler?
    private var toggleHandler: CommandHandler?
    private var nextTrackHandler: CommandHandler?
    private var previousTrackHandler: CommandHandler?
    private var seekHandler: SeekHandler?

    init() {
        setupRemoteCommands()
    }

    func configure(
        play: @escaping CommandHandler,
        pause: @escaping CommandHandler,
        toggle: @escaping CommandHandler,
        next: @escaping CommandHandler,
        previous: @escaping CommandHandler,
        seek: @escaping SeekHandler,
    ) {
        playHandler = play
        pauseHandler = pause
        toggleHandler = toggle
        nextTrackHandler = next
        previousTrackHandler = previous
        seekHandler = seek
    }

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        // Play
        center.playCommand.isEnabled = true
        center.playCommand.addTarget { [weak self] _ in
            self?.playHandler?()
            return .success
        }

        // Pause
        center.pauseCommand.isEnabled = true
        center.pauseCommand.addTarget { [weak self] _ in
            self?.pauseHandler?()
            return .success
        }

        // Toggle Play/Pause
        center.togglePlayPauseCommand.isEnabled = true
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.toggleHandler?()
            return .success
        }

        // Next Track
        center.nextTrackCommand.isEnabled = true
        center.nextTrackCommand.addTarget { [weak self] _ in
            self?.nextTrackHandler?()
            return .success
        }

        // Previous Track
        center.previousTrackCommand.isEnabled = true
        center.previousTrackCommand.addTarget { [weak self] _ in
            self?.previousTrackHandler?()
            // We return success even if we technically just sought to 0,
            // as from the user's perspective the command was handled.
            return .success
        }

        // Seek
        center.changePlaybackPositionCommand.isEnabled = true
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent
            else { return .commandFailed }
            self?.seekHandler?(event.positionTime)
            return .success
        }
    }

    private var currentTrackID: UUID?

    func update(track: Track?, isPlaying: Bool, currentTime: Double, duration: Double) {
        // Update current track ID to track validity of async operations
        currentTrackID = track?.id

        var info: [String: Any] = [:]

        if let track {
            info[MPMediaItemPropertyTitle] = track.title
            info[MPMediaItemPropertyArtist] = track.artist
            info[MPMediaItemPropertyAlbumTitle] = track.album
        }

        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPMediaItemPropertyPlaybackDuration] = duration
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0

        // Set basic info first (synchronously on caller thread, usually main)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info

        // Then load artwork asynchronously and update again
        if let track {
            let requestID = track.id
            Task {
                if let artworkImage = await track.loadArtwork() {
                    let artwork = MPMediaItemArtwork(boundsSize: artworkImage.size) { _ in
                        artworkImage
                    }
                    await MainActor.run {
                        // Guard: Only update if we are still playing the same track
                        guard self.currentTrackID == requestID else { return }

                        // Re-fetch current info to avoid overwriting recent updates
                        var updatedInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? info
                        updatedInfo[MPMediaItemPropertyArtwork] = artwork
                        MPNowPlayingInfoCenter.default().nowPlayingInfo = updatedInfo
                    }
                }
            }
        }
    }

    func clear() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
}
