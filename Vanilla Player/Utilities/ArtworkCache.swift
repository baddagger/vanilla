import AppKit
import CryptoKit
import Foundation

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

    static func remove(for url: URL) {
        let key = cacheKey(for: url)
        let fileURL = directory.appendingPathComponent(key)
        try? FileManager.default.removeItem(at: fileURL)
    }

    static func cleanup(keeping urls: Set<URL>) {
        let keptKeys = Set(urls.map { cacheKey(for: $0) })
        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil,
            )
            for fileURL in files {
                let filename = fileURL.lastPathComponent
                if !keptKeys.contains(filename) {
                    try? FileManager.default.removeItem(at: fileURL)
                    print("Cleaned up orphaned artwork cache: \(filename)")
                }
            }
        } catch {
            print("Failed to cleanup artwork cache: \(error)")
        }
    }
}
