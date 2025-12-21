import AppKit
import AVFoundation
import Foundation

enum TrackMetadataExtractor {
    struct Metadata {
        let title: String
        let artist: String
        let album: String
        let hasArtwork: Bool
        let bookmarkData: Data?
    }

    static func extract(from url: URL) async -> Metadata? {
        // Start accessing security-scoped resource first
        let isSecured = url.startAccessingSecurityScopedResource()
        defer {
            if isSecured {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let asset = AVAsset(url: url)

        // Basic validation using modern async loading
        guard let metadata = try? await asset.load(.commonMetadata) else {
            // Fallback for older AVAsset API if needed
            let legacyMetadata = asset.commonMetadata
            if legacyMetadata.isEmpty { return nil }
            return processMetadata(legacyMetadata, asset: asset, url: url)
        }

        return processMetadata(metadata, asset: asset, url: url)
    }

    private static func extractArtworkData(from metadata: [AVMetadataItem]) -> Data? {
        if let artworkItem = metadata.first(where: { $0.commonKey == .commonKeyArtwork }),
           let data = artworkItem.dataValue
        {
            return data
        }
        return nil
    }

    private static func processMetadata(_ metadata: [AVMetadataItem], asset: AVAsset,
                                        url: URL) -> Metadata
    {
        // Create a security bookmark to maintain access later
        var bookmark: Data?
        do {
            bookmark = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil,
            )
        } catch {
            print("Failed to create bookmark for \(url): \(error)")
        }

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
        // Handle Artwork: Extract and Cache
        var foundArtwork = false
        if let data = extractArtworkData(from: metadata) ??
            extractArtworkData(from: asset.metadata)
        {
            foundArtwork = true
            ArtworkCache.save(data: data, for: url)
        } else {
            ArtworkCache.remove(for: url)
        }

        return Metadata(
            title: title,
            artist: artist,
            album: album,
            hasArtwork: foundArtwork,
            bookmarkData: bookmark,
        )
    }

    static func reExtractAndCacheArtwork(for track: Track) async -> NSImage? {
        // Start accessing security-scoped resource
        let resolved = track.resolvedURL() ?? track.url
        let isSecured = resolved.startAccessingSecurityScopedResource()
        defer {
            if isSecured {
                resolved.stopAccessingSecurityScopedResource()
            }
        }

        let asset = AVAsset(url: resolved)
        guard let metadata = try? await asset.load(.commonMetadata) else {
            return nil
        }

        if let data = extractArtworkData(from: metadata) ??
            extractArtworkData(from: asset.metadata)
        {
            ArtworkCache.save(data: data, for: track.url)
            return NSImage(data: data)
        }

        return nil
    }
}
