import AppKit
import AVFoundation
import CryptoKit
import Foundation

struct Track: Identifiable, Equatable, Codable {
    let id: UUID
    let url: URL
    let title: String
    let artist: String
    let album: String
    let hasArtwork: Bool
    let bookmarkData: Data?

    // Default Equatable implementation will compare all stored properties, which is what we want
    // to detect metadata changes.

    init(url: URL) {
        id = UUID()
        self.url = url

        // Use common initialization logic
        let (title, artist, album, hasArtwork, bookmark) = Track.extractMetadata(from: url)
        self.title = title
        self.artist = artist
        self.album = album
        self.hasArtwork = hasArtwork
        bookmarkData = bookmark
    }

    /// Re-initializes a track from an existing one, refreshing metadata from the file.
    /// - Parameters:
    ///   - track: The original track to update.
    ///   - url: An optional resolved security-scoped URL. If provided, this is used for metadata
    /// access.
    init(refreshing track: Track, with url: URL? = nil) {
        id = track.id // Preserve ID
        // Use the new URL if provided, otherwise fallback to existing (though existing might be
        // stale)
        let effectiveURL = url ?? track.url
        self.url = effectiveURL

        // Use effectiveURL for extraction ensure we use the accessible resource
        let (title, artist, album, hasArtwork, bookmark) = Track.extractMetadata(from: effectiveURL)
        self.title = title
        self.artist = artist
        self.album = album
        self.hasArtwork = hasArtwork
        // access existing bookmark if new one fails? Usually we want fresh bookmark if accessing
        // file again.
        bookmarkData = bookmark ?? track.bookmarkData
    }

    private static func extractMetadata(from url: URL) -> (String, String, String, Bool, Data?) {
        // Start accessing security-scoped resource first
        let isSecured = url.startAccessingSecurityScopedResource()
        defer {
            if isSecured {
                url.stopAccessingSecurityScopedResource()
            }
        }

        // Create a security bookmark to maintain access later
        var bookmark: Data? = nil
        do {
            bookmark = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil,
            )
        } catch {
            print("Failed to create bookmark for \(url): \(error)")
        }

        let asset = AVAsset(url: url)
        let metadata = asset.commonMetadata

        let title: String = if let titleItem = metadata
            .first(where: { $0.commonKey == .commonKeyTitle }),
            let titleStr = titleItem.stringValue
        {
            titleStr
        } else {
            url.deletingPathExtension().lastPathComponent
        }

        let artist: String = if let artistItem = metadata
            .first(where: { $0.commonKey == .commonKeyArtist }),
            let artistStr = artistItem.stringValue
        {
            artistStr
        } else {
            ""
        }

        let album: String = if let albumItem = metadata
            .first(where: { $0.commonKey == .commonKeyAlbumName }),
            let albumStr = albumItem.stringValue
        {
            albumStr
        } else {
            ""
        }

        // Handle Artwork: Extract and Cache
        var foundArtwork = false
        if let artworkItem = metadata.first(where: { $0.commonKey == .commonKeyArtwork }),
           let data = artworkItem.dataValue
        {
            foundArtwork = true
            ArtworkCache.save(data: data, for: url)
        } else {
            // Try to find artwork in all formats if commonKey failed (fallback)
            let allItems = asset.metadata
            if let artworkItem = allItems.first(where: { $0.commonKey == .commonKeyArtwork }),
               let data = artworkItem.dataValue
            {
                foundArtwork = true
                ArtworkCache.save(data: data, for: url)
            }
        }

        return (title, artist, album, foundArtwork, bookmark)
    }

    // Custom decoding to handle restoring bookmark access if needed, though simplified here.
    // Standard Codable is sufficient as long as we handle bookmark resolution on playback/access.

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

    func loadArtwork() -> NSImage? {
        guard hasArtwork else { return nil }
        return ArtworkCache.load(for: url)
    }
}

enum ArtworkCache {
    static let directory: URL = {
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        let cacheDir = paths[0].appendingPathComponent("VanillaPlayer")
            .appendingPathComponent("Artworks")
        do {
            try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
            print("Artwork Cache Directory: \(cacheDir.path)")
        } catch {
            print("Failed to create cache directory: \(error)")
        }
        return cacheDir
    }()

    static func cacheKey(for url: URL) -> String {
        let data = url.absoluteString.data(using: .utf8) ?? Data()
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    static func save(data: Data, for url: URL) {
        let key = cacheKey(for: url)
        let fileURL = directory.appendingPathComponent(key)

        // Always overwrite to ensure we have the latest artwork content (e.g. if file metadata
        // changed)
        // If performance becomes an issue, we could compare data hash, but for now correctness is
        // priority.

        do {
            try data.write(to: fileURL)
            // print("Saved artwork for \(url.lastPathComponent)")
        } catch {
            print("Failed to cache artwork for \(url): \(error)")
        }
    }

    static func load(for url: URL) -> NSImage? {
        let key = cacheKey(for: url)
        let fileURL = directory.appendingPathComponent(key)
        // print("Loading artwork from: \(fileURL.path)")
        guard let data = try? Data(contentsOf: fileURL) else {
            // print("Failed to read data from \(fileURL.path)")
            return nil
        }
        return NSImage(data: data)
    }
}
