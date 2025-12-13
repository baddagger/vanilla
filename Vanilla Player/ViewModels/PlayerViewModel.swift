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
        static let isShuffleEnabled = "isShuffleEnabled"
        static let repeatMode = "repeatMode"
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

        // Whenever tracks change, we need to update our shuffle queue
        libraryManager.$tracks
            .map { _ in }
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updatePlaybackQueue()
            }
            .store(in: &cancellables)

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

    // MARK: - Playback Mode

    enum RepeatMode: Int, CaseIterable {
        case off
        case all
        case one

        var next: RepeatMode {
            let all = Self.allCases
            let idx = all.firstIndex(of: self)!
            let nextIdx = (idx + 1) % all.count
            return all[nextIdx]
        }
    }

    @Published var isShuffleEnabled: Bool = false {
        didSet {
            updatePlaybackQueue()
            savePlaybackState()
        }
    }

    @Published var repeatMode: RepeatMode = .off {
        didSet {
            savePlaybackState()
        }
    }

    /// The randomized or sequential list of track INDICES.
    /// Accessing tracks[playbackQueue[i]] gives the track.
    private var playbackQueue: [Int] = []

    /// The current index play head within the playbackQueue (NOT tracks)
    private var queueIndex: Int = 0

    // MARK: - Queue Management

    private func updatePlaybackQueue() {
        let allIndices = Array(tracks.indices)

        if isShuffleEnabled {
            if let current = currentTrackIndex {
                // Keep current playing track first (or handling it gracefully), then shuffle the
                // rest
                var others = allIndices.filter { $0 != current }
                others.shuffle()
                playbackQueue = [current] + others
                queueIndex = 0
            } else {
                playbackQueue = allIndices.shuffled()
                queueIndex = 0 // Reset query index if nothing is playing
            }
        } else {
            playbackQueue = allIndices
            if let current = currentTrackIndex {
                queueIndex = current // In linear mode, queue index matches track index
            } else {
                queueIndex = 0
            }
        }
    }

    // MARK: - Playback Controls Logic Override

    func toggleShuffle() {
        isShuffleEnabled.toggle()
    }

    func toggleRepeat() {
        repeatMode = repeatMode.next
    }

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
        if trackURL.startAccessingSecurityScopedResource() {
            currentSecurityScopedURL = trackURL
        } else {
            // ... fallback logic (same as original) ...
            if let parentSource = libraryManager.source(containing: trackURL),
               let sourceURL = parentSource.resolvedURL()
            {
                if sourceURL.startAccessingSecurityScopedResource() {
                    currentSecurityScopedURL = sourceURL
                } else {
                    print("ERROR: Failed to access permissions")
                }
            }
        }

        audioManager.play(url: trackURL)
        currentTrackIndex = index

        // Sync Queue
        if isShuffleEnabled {
            // In shuffle mode, if we manually pick a track, we regenerate the queue starting with
            // this track
            // to avoid confusing "Next" behavior.
            updatePlaybackQueue()
        } else {
            queueIndex = index
        }
    }

    func playPause() {
        guard currentTrackIndex != nil else { return }
        if isPlaying {
            audioManager.pause()
        } else {
            audioManager.resume()
        }
    }

    func seek(to time: TimeInterval) {
        audioManager.seek(to: time)
    }

    func nextTrack() {
        if tracks.isEmpty { return }

        // Handle Repeat One
        if repeatMode == .one, currentTrackIndex != nil {
            audioManager.seek(to: 0)
            audioManager.resume()
            return
        }

        let nextQueueIndex = queueIndex + 1

        if nextQueueIndex < playbackQueue.count {
            queueIndex = nextQueueIndex
            playTrack(at: playbackQueue[queueIndex])
        } else {
            // End of queue
            if repeatMode == .all {
                // Loop back to start
                queueIndex = 0
                playTrack(at: playbackQueue[queueIndex])
            } else {
                // Stop
                audioManager.pause()
                audioManager.seek(to: 0)
                isPlaying = false
            }
        }
    }

    func previousTrack() {
        if tracks.isEmpty { return }

        if currentTime > 3.0 {
            audioManager.seek(to: 0)
            return
        }

        // If Shuffle is ON, we go back in history (simple implementation: use queue)
        // If Shuffle is OFF, we go previous index

        let prevQueueIndex = queueIndex - 1
        if prevQueueIndex >= 0 {
            queueIndex = prevQueueIndex
            playTrack(at: playbackQueue[queueIndex])
        } else {
            // We are at the start of the queue
            if repeatMode == .all {
                // Wrap around to end
                queueIndex = playbackQueue.count - 1
                playTrack(at: playbackQueue[queueIndex])
            } else {
                playTrack(at: playbackQueue[0])
            }
        }
    }

    // MARK: - Playback State Persistence

    func savePlaybackState() {
        // Always save settings
        UserDefaults.standard.set(isShuffleEnabled, forKey: UserDefaultsKeys.isShuffleEnabled)
        UserDefaults.standard.set(repeatMode.rawValue, forKey: UserDefaultsKeys.repeatMode)

        // Only save track info if we have a valid track.
        // If currentTrack is nil (e.g. during app launch/restore), we should NOT wipe the saved state.
        guard let track = currentTrack else { return }

        UserDefaults.standard.set(track.url.absoluteString, forKey: UserDefaultsKeys.lastTrackURL)
        UserDefaults.standard.set(currentTime, forKey: UserDefaultsKeys.lastPlaybackPosition)
    }

    private func restorePlaybackState() {
        // Restore Shuffle/Repeat
        isShuffleEnabled = UserDefaults.standard.bool(forKey: UserDefaultsKeys.isShuffleEnabled)
        if let mode = RepeatMode(rawValue: UserDefaults.standard.integer(forKey: UserDefaultsKeys.repeatMode)) {
            repeatMode = mode
        }

        // Force queue init
        updatePlaybackQueue()

        guard let urlString = UserDefaults.standard.string(forKey: UserDefaultsKeys.lastTrackURL),
              let savedURL = URL(string: urlString)
        else {
            return
        }

        let savedPosition = UserDefaults.standard
            .double(forKey: UserDefaultsKeys.lastPlaybackPosition)

        if let index = tracks.firstIndex(where: { $0.url == savedURL }) {
            // Original logic to load track...
            // Copy-pasted from original for safety, condensed for brevity in diff
            let track = tracks[index]
            guard let trackURL = track.resolvedURL() else { return }

            currentSecurityScopedURL?.stopAccessingSecurityScopedResource()
            if trackURL.startAccessingSecurityScopedResource() {
                currentSecurityScopedURL = trackURL
            } else if let parentSource = libraryManager.source(containing: trackURL),
                      let sourceURL = parentSource.resolvedURL(),
                      sourceURL.startAccessingSecurityScopedResource()
            {
                currentSecurityScopedURL = sourceURL
            }

            audioManager.play(url: trackURL)
            audioManager.pause()
            audioManager.seek(to: savedPosition)
            currentTrackIndex = index

            // Sync Queue Index
            if isShuffleEnabled {
                updatePlaybackQueue()
            } else {
                queueIndex = index
            }
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
        let shouldProcess = isAppActive && isWindowVisible
        audioManager.setAppActiveState(shouldProcess)
    }

    deinit {
        currentSecurityScopedURL?.stopAccessingSecurityScopedResource()
    }
}
