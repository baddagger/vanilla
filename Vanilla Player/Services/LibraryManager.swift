import AVFoundation
import Combine
import Foundation

class LibraryManager: ObservableObject {
    @Published var sources: [Source] = []
    @Published var tracks: [Track] = []
    @Published var isScanning: Bool = false

    private let libraryFileName = "Library.plist"
    private var cancellables = Set<AnyCancellable>()

    // Application Support Directory
    private var libraryFileURL: URL? {
        guard let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
        ).first
        else { return nil }
        let appDir = appSupport.appendingPathComponent("VanillaPlayer")
        // Ensure dir exists
        try? FileManager.default.createDirectory(
            at: appDir,
            withIntermediateDirectories: true,
            attributes: nil,
        )
        return appDir.appendingPathComponent(libraryFileName)
    }

    init() {
        loadLibrary()
        // Auto-save sources changes
        $sources
            .dropFirst()
            .debounce(for: .seconds(2), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.saveLibrary()
            }
            .store(in: &cancellables)
    }

    // MARK: - Source Management

    @discardableResult
    func addSource(url: URL) async -> [Track] {
        // Determine type
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            let type: SourceType = isDirectory.boolValue ? .folder : .file

            // Check for duplicates
            if let existingSource = sources.first(where: { $0.url == url }) {
                return await scanSource(existingSource, mode: .add)
            }

            let source = Source(url: url, type: type)
            sources.append(source)
            return await scanSource(source, mode: .add)
        }
        return []
    }

    func removeSource(_ source: Source) {
        if let index = sources.firstIndex(of: source) {
            sources.remove(at: index)
            // Remove tracks belonging to this source
            // Note: simple removal is tricky if tracks are mixed.
            // Better strategy: Re-scan remaining, OR simpler: Remove tracks whose URL starts with
            // source URL (for
            // folder) or matches (for file).
            cleanupTracks(forRemovedSource: source)
            saveLibrary()
        }
    }

    private func cleanupTracks(forRemovedSource source: Source) {
        if source.type == .file {
            tracks.removeAll { $0.url == source.url }
        } else {
            // For folders, remove if it originates from this folder
            tracks.removeAll { $0.url.path.hasPrefix(source.url.path) }
        }
    }

    /// Finds the Source that contains the given URL.
    /// - Parameter url: The URL to search for.
    /// - Returns: The Source that manages this URL, or nil if none found.
    func source(containing url: URL) -> Source? {
        // 1. Check for direct file match
        if let fileSource = sources.first(where: { $0.type == .file && $0.url == url }) {
            return fileSource
        }

        // 2. Check for folder containment
        // We look for the folder source with the longest path prefix match to be precise
        let folderSources = sources.filter { $0.type == .folder }
        let sortedFolders = folderSources.sorted { $0.url.path.count > $1.url.path.count }

        for source in sortedFolders {
            if url.path.hasPrefix(source.url.path) {
                return source
            }
        }

        return nil
    }

    // MARK: - Scanning

    enum ScanMode {
        case quick // Startup: Check existence, load metadata
        case full // Re-scan folders for new content
        case add // Single source addition
    }

    func startStartupScan() {
        Task {
            await performScan(mode: .quick)
        }
    }

    func startFullScan() {
        Task {
            await performScan(mode: .full)
        }
    }

    @discardableResult
    private func scanSource(_ source: Source, mode _: ScanMode) async -> [Track] {
        let (newTracks, allURLs) = collectTracks(from: source, existingTracks: tracks)

        if !newTracks.isEmpty {
            await MainActor.run {
                self.tracks.append(contentsOf: newTracks)
            }
        }

        // Return all tracks found in this scan (existing matched + new)
        let allURLSet = Set(allURLs)

        let existingMatched = await MainActor.run {
            self.tracks.filter { allURLSet.contains($0.url) && !newTracks.contains($0) }
        }

        return existingMatched + newTracks
    }

    @MainActor
    private func performScan(mode: ScanMode) async {
        isScanning = true
        defer { isScanning = false }

        // 1. Validate Access to Sources
        var validSources: [Source] = []
        for source in sources {
            if let resolved = source.resolvedURL() {
                let isSecured = resolved.startAccessingSecurityScopedResource()
                if FileManager.default.fileExists(atPath: resolved.path) {
                    validSources.append(source)
                }
                if isSecured { resolved.stopAccessingSecurityScopedResource() }
            }
        }
        sources = validSources

        // 2. Scan Tracks
        var currentTracks = tracks

        // Quick Scan: Validate existing tracks
        if mode == .quick || mode == .full {
            var validatedTracks: [Track] = []
            for track in currentTracks {
                // If we have a bookmark, use it.
                if let resolved = track.resolvedURL() {
                    let isSecured = resolved.startAccessingSecurityScopedResource()
                    if FileManager.default.fileExists(atPath: resolved.path) {
                        validatedTracks.append(track)
                    }
                    if isSecured { resolved.stopAccessingSecurityScopedResource() }
                } else {
                    // Try checking if it exists at original URL (unlikely if sandboxed, but
                    // fallback)
                    if FileManager.default.fileExists(atPath: track.url.path) {
                        validatedTracks.append(track)
                    }
                }
            }
            currentTracks = validatedTracks
        }

        // Full Scan: Crawl folders again
        if mode == .full {
            var allFoundURLs = Set<URL>()
            var newlyFoundTracks: [Track] = []

            // We need to scan sources and create tracks for NEW items while source is open.
            // We can't do the simple diff approach anymore because we need the Scope to be open for
            // Track creation.

            for source in sources {
                // Pass currentTracks so we don't recreate existing ones
                let (newTracks, sourceURLs) = collectTracks(
                    from: source,
                    existingTracks: currentTracks,
                )
                newlyFoundTracks.append(contentsOf: newTracks)
                allFoundURLs.formUnion(sourceURLs)
            }

            // Add new tracks
            currentTracks.append(contentsOf: newlyFoundTracks)

            // Filter deleted tracks (Strict Sync)
            // Only keep tracks that were found in the current scan
            currentTracks = currentTracks.filter { allFoundURLs.contains($0.url) }
        }

        tracks = currentTracks
        saveLibrary()
    }

    /// Scans a source and returns newly created Tracks (with valid bookmarks) and all found URLs.
    /// - Parameters:
    ///   - source: The source to scan.
    ///   - existingTracks: Existing tracks to check against (to avoid recreating).
    /// - Returns: A tuple of (New Tracks, All URLs found in source).
    private func collectTracks(from source: Source, existingTracks: [Track]) -> ([Track], [URL]) {
        guard let url = source.resolvedURL() else { return ([], []) }

        let isSecured = url.startAccessingSecurityScopedResource()
        defer { if isSecured { url.stopAccessingSecurityScopedResource() } }

        var newTracks: [Track] = []
        var allURLs: [URL] = []
        let existingURLs = Set(existingTracks.map(\.url))

        let supportedExtensions = ["mp3", "m4a", "wav", "aiff", "aif", "aac", "flac", "caf"]

        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            if isDirectory.boolValue {
                if let enumerator = FileManager.default.enumerator(
                    at: url,
                    includingPropertiesForKeys: [.isRegularFileKey],
                    options: [.skipsHiddenFiles, .skipsPackageDescendants],
                ) {
                    for case let fileURL as URL in enumerator {
                        if supportedExtensions.contains(fileURL.pathExtension.lowercased()) {
                            allURLs.append(fileURL)

                            // If it's new, create Track NOW while we have access
                            // This ensures the Track can create its own bookmark successfully.
                            if !existingURLs.contains(fileURL) {
                                let track = Track(url: fileURL)
                                newTracks.append(track)
                            }
                        }
                    }
                }
            } else {
                // Single file source
                if supportedExtensions.contains(url.pathExtension.lowercased()) {
                    allURLs.append(url)
                    if !existingURLs.contains(url) {
                        let track = Track(url: url)
                        newTracks.append(track)
                    }
                }
            }
        }

        return (newTracks, allURLs)
    }

    // MARK: - Persistence

    private struct LibraryData: Codable {
        let sources: [Source]
        let tracks: [Track]
    }

    private func saveLibrary() {
        guard let url = libraryFileURL else { return }

        let data = LibraryData(sources: sources, tracks: tracks)
        do {
            let encoder = PropertyListEncoder()
            encoder.outputFormat = .binary
            let encodedData = try encoder.encode(data)
            try encodedData.write(to: url)
        } catch {
            print("Failed to save library: \(error)")
        }
    }

    private func loadLibrary() {
        guard let url = libraryFileURL,
              FileManager.default.fileExists(atPath: url.path) else { return }

        do {
            let data = try Data(contentsOf: url)
            let decoder = PropertyListDecoder()
            let libraryData = try decoder.decode(LibraryData.self, from: data)

            sources = libraryData.sources
            tracks = libraryData.tracks

            // Validate access immediately? Or wait for scan. Scan is safer for async.
        } catch {
            print("Failed to load library: \(error)")
        }
    }
}
