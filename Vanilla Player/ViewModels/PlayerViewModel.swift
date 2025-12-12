import AVFoundation
import Combine
import SwiftUI

class PlayerViewModel: NSObject, ObservableObject {
    @Published var tracks: [Track] = []
    @Published var currentTrackIndex: Int?

    // Exposed properties synced from AudioEngineManager
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    // REMOVED: meteringLevels to prevent 30fps view invalidation
    @Published var volume: Float = 1.0
    @Published var bass: Float = 0.0

    // ViewModel Split: Visualizer updates isolated here
    let visualizerViewModel: VisualizerViewModel

    // UserDefaults keys for playback state persistence
    private enum UserDefaultsKeys {
        static let lastTrackURL = "lastPlayingTrackURL"
        static let lastPlaybackPosition = "lastPlaybackPosition"
    }

    // Library Manager
    let libraryManager = LibraryManager()

    var currentTrack: Track? {
        guard let index = currentTrackIndex, tracks.indices.contains(index) else { return nil }
        return tracks[index]
    }

    private var audioManager = AudioEngineManager()
    private var currentSecurityScopedURL: URL?
    private var cancellables = Set<AnyCancellable>()

    override init() {
        // Initialize child VM with dependency
        let audioMgr = AudioEngineManager()
        audioManager = audioMgr
        visualizerViewModel = VisualizerViewModel(audioManager: audioMgr)

        super.init()
        setupBindings()

        // Initial Scan
        libraryManager.startStartupScan()

        $volume.sink { [weak self] newVolume in
            self?.audioManager.setPlayerVolume(newVolume)
        }.store(in: &cancellables)

        $bass.sink { [weak self] newBass in
            self?.audioManager.setBass(newBass)
        }.store(in: &cancellables)

        // Restore playback state after tracks are loaded
        libraryManager.$tracks
            .first(where: { !$0.isEmpty })
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.restorePlaybackState()
            }
            .store(in: &cancellables)
    }

    private func setupBindings() {
        // Sync Library Tracks to Player Tracks
        libraryManager.$tracks
            .map { Array($0.reversed()) }
            .assign(to: &$tracks)

        audioManager.$isPlaying.assign(to: &$isPlaying)
        audioManager.$currentTime.assign(to: &$currentTime)
        audioManager.$duration.assign(to: &$duration)
        // REMOVED: audioManager.$meteringLevels.assign(to: &$meteringLevels)

        audioManager.onPlaybackFinished = { [weak self] in
            self?.nextTrack()
        }
    }

    // MARK: - File Management

    func addFiles(urls: [URL]) {
        Task {
            var addedTracks: [Track] = []

            for url in urls {
                let tracks = await libraryManager.addSource(url: url)
                addedTracks.append(contentsOf: tracks)
            }

            // Auto-play logic
            if let firstNewTrack = addedTracks.first {
                await MainActor.run {
                    // Find the index of the new track in the main list
                    if let index = tracks.firstIndex(of: firstNewTrack) {
                        playTrack(at: index)
                    }
                }
            }
        }
    }

    // MARK: - Playback Controls

    func playTrack(at index: Int) {
        guard tracks.indices.contains(index) else { return }

        if currentTrackIndex == index {
            if !isPlaying {
                audioManager.resume()
            }
            return
        }

        let track = tracks[index]

        guard let trackURL = track.resolvedURL() else {
            print("Failed to resolve URL for track: \(track.title)")
            return
        }

        currentSecurityScopedURL?.stopAccessingSecurityScopedResource()

        // We need to maintain access to the file while playing
        // Try accessing the track directly
        if trackURL.startAccessingSecurityScopedResource() {
            currentSecurityScopedURL = trackURL
        } else {
            // Fallback: This track might be part of a folder source we need to unlock
            if let parentSource = libraryManager.source(containing: trackURL),
               let sourceURL = parentSource.resolvedURL()
            {
                // Access the PARENT source
                if sourceURL.startAccessingSecurityScopedResource() {
                    currentSecurityScopedURL = sourceURL
                } else {
                    print(
                        "ERROR: Failed to access both track URL and parent Source URL for:",
                        track.title,
                    )
                }
            } else {
                print(
                    "WARNING: Track startAccessingSecurityScopedResource failed,",
                    "no parent source found for:",
                    track.title,
                )
            }
        }

        audioManager.play(url: trackURL)
        currentTrackIndex = index
    }

    func playPause() {
        guard currentTrackIndex != nil else { return }
        if isPlaying {
            audioManager.pause()
        } else {
            audioManager.resume()
        }
    }

    func nextTrack() {
        guard let currentIndex = currentTrackIndex else {
            if !tracks.isEmpty { playTrack(at: 0) }
            return
        }

        let nextIndex = currentIndex + 1
        if nextIndex < tracks.count {
            playTrack(at: nextIndex)
        } else {
            // End of playlist reached
            audioManager.pause()
            audioManager.seek(to: 0)
            isPlaying = false
        }
    }

    func previousTrack() {
        guard let currentIndex = currentTrackIndex else {
            if !tracks.isEmpty { playTrack(at: 0) }
            return
        }

        if currentTime > 3.0 {
            audioManager.seek(to: 0)
            return
        }

        let prevIndex = currentIndex > 0 ? currentIndex - 1 : tracks.count - 1
        playTrack(at: prevIndex)
    }

    func seek(to time: TimeInterval) {
        audioManager.seek(to: time)
    }

    // MARK: - Playback State Persistence

    /// Saves the current playback state (track URL and position) to UserDefaults
    func savePlaybackState() {
        guard let track = currentTrack else {
            // Clear saved state if no track is playing
            UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.lastTrackURL)
            UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.lastPlaybackPosition)
            return
        }

        UserDefaults.standard.set(track.url.absoluteString, forKey: UserDefaultsKeys.lastTrackURL)
        UserDefaults.standard.set(currentTime, forKey: UserDefaultsKeys.lastPlaybackPosition)
    }

    /// Restores the playback state from UserDefaults (loads track paused at saved position)
    private func restorePlaybackState() {
        guard let urlString = UserDefaults.standard.string(forKey: UserDefaultsKeys.lastTrackURL),
              let savedURL = URL(string: urlString)
        else {
            return
        }

        let savedPosition = UserDefaults.standard
            .double(forKey: UserDefaultsKeys.lastPlaybackPosition)

        // Find the track in the current library
        if let index = tracks.firstIndex(where: { $0.url == savedURL }) {
            // Load the track but don't auto-play
            let track = tracks[index]

            guard let trackURL = track.resolvedURL() else {
                print("Failed to resolve URL for restored track: \(track.title)")
                return
            }

            currentSecurityScopedURL?.stopAccessingSecurityScopedResource()

            // Try accessing the track directly
            if trackURL.startAccessingSecurityScopedResource() {
                currentSecurityScopedURL = trackURL
            } else {
                // Fallback: This track might be part of a folder source we need to unlock
                if let parentSource = libraryManager.source(containing: trackURL),
                   let sourceURL = parentSource.resolvedURL()
                {
                    // Access the PARENT source
                    if sourceURL.startAccessingSecurityScopedResource() {
                        currentSecurityScopedURL = sourceURL
                    } else {
                        print(
                            "ERROR: Failed to access both track URL",
                            "and parent Source URL for restored track:",
                            track.title,
                        )
                    }
                } else {
                    print(
                        "WARNING: Track startAccessingSecurityScopedResource failed,",
                        "no parent source found for restored track:",
                        track.title,
                    )
                }
            }

            // Load the track paused at the saved position
            audioManager.play(url: trackURL)
            audioManager.pause()
            audioManager.seek(to: savedPosition)
            currentTrackIndex = index
        }
    }

    @Published var isAppActive = true
    @Published var isWindowVisible = true

    func setAppActive(_ active: Bool) {
        isAppActive = active
        updateProcessingState()
    }

    func setWindowVisible(_ visible: Bool) {
        isWindowVisible = visible
        updateProcessingState()
    }

    private func updateProcessingState() {
        // Only process audio visualization if the app is active AND the window is visible
        let shouldProcess = isAppActive && isWindowVisible
        audioManager.setAppActiveState(shouldProcess)
    }

    deinit {
        currentSecurityScopedURL?.stopAccessingSecurityScopedResource()
    }
}
