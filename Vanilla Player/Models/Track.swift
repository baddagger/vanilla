import AppKit
import AVFoundation
import Foundation

struct Track: Identifiable, Equatable, Codable {
    let id: UUID
    let url: URL
    let title: String
    let artist: String
    let album: String
    let hasArtwork: Bool
    let bookmarkData: Data?

    /// Internal initializer for creating a Track with pre-extracted metadata
    init(url: URL, metadata: TrackMetadataExtractor.Metadata) {
        id = UUID()
        self.url = url
        title = metadata.title
        artist = metadata.artist
        album = metadata.album
        hasArtwork = metadata.hasArtwork
        bookmarkData = metadata.bookmarkData
    }

    /// Internal initializer for refreshing a Track
    private init(id: UUID, url: URL, metadata: TrackMetadataExtractor.Metadata) {
        self.id = id
        self.url = url
        title = metadata.title
        artist = metadata.artist
        album = metadata.album
        hasArtwork = metadata.hasArtwork
        bookmarkData = metadata.bookmarkData
    }

    /// Static factory method to asynchronously create a track from a URL
    static func load(from url: URL) async -> Track? {
        guard let metadata = await TrackMetadataExtractor.extract(from: url) else {
            return nil
        }
        return Track(url: url, metadata: metadata)
    }

    /// Asynchronously refreshes metadata for an existing track
    func refreshing() async -> Track {
        // Use the resolved URL to ensure we have access if it's security-scoped
        let effectiveURL = resolvedURL() ?? url

        if let metadata = await TrackMetadataExtractor.extract(from: effectiveURL) {
            return Track(id: id, url: url, metadata: metadata)
        } else {
            // Return self if refresh fails
            return self
        }
    }

    /// Resolves the URL from the security bookmark if available
    func resolvedURL() -> URL? {
        guard let bookmarkData else { return url }

        var isStale = false
        do {
            let resolvedURL = try URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale,
            )
            return resolvedURL
        } catch {
            print("Failed to resolve bookmark: \(error)")
            return url
        }
    }

    func loadArtwork() async -> NSImage? {
        guard hasArtwork else { return nil }
        if let cached = ArtworkCache.load(for: url) {
            return cached
        }
        // Cache miss but track has artwork - re-extract
        return await TrackMetadataExtractor.reExtractAndCacheArtwork(for: self)
    }
}
