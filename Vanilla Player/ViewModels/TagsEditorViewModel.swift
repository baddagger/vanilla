import AppKit
import Foundation

@MainActor
class TagsEditorViewModel: ObservableObject {
    @Published var title: String = ""
    @Published var artist: String = ""
    @Published var album: String = ""
    @Published var trackNumber: String = ""
    @Published var year: String = ""
    @Published var genre: String = ""
    @Published var comment: String = ""

    // Artwork
    @Published var artwork: NSImage?
    private var originalArtwork: NSImage?
    @Published var artworkChanged: Bool = false

    // Read-only audio properties
    @Published var duration: Int = 0
    @Published var bitrate: Int = 0
    @Published var sampleRate: Int = 0
    @Published var channels: Int = 0
    @Published var bitDepth: Int = 0
    @Published var fileSize: Int64 = 0
    @Published var fileFormat: String = ""

    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var isSaved: Bool = false

    // Store original values to check for changes
    private var originalTitle: String = ""
    private var originalArtist: String = ""
    private var originalAlbum: String = ""
    private var originalTrackNumber: String = ""
    private var originalYear: String = ""
    private var originalGenre: String = ""
    private var originalComment: String = ""

    var hasChanges: Bool {
        title != originalTitle ||
            artist != originalArtist ||
            album != originalAlbum ||
            trackNumber != originalTrackNumber ||
            year != originalYear ||
            genre != originalGenre ||
            comment != originalComment ||
            artworkChanged
    }

    let track: Track
    private var fileURL: URL?

    init(track: Track) {
        self.track = track
        loadTags()
    }

    private func loadTags() {
        isLoading = true
        errorMessage = nil

        guard let url = track.resolvedURL() else {
            errorMessage = "Cannot access file"
            isLoading = false
            return
        }

        fileURL = url

        // Start security-scoped access
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        // Use Obj-C Wrapper
        do {
            let data = try TagLibWrapper.readTags(from: url)
            title = data.title ?? ""
            artist = data.artist ?? ""
            album = data.album ?? ""
            trackNumber = data.trackNumber ?? ""
            year = data.year ?? ""
            genre = data.genre ?? ""
            comment = data.comment ?? ""

            duration = data.duration
            bitrate = data.bitrate
            sampleRate = data.sampleRate
            channels = data.channels
            bitDepth = data.bitDepth

            // Get file info
            if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path) {
                fileSize = attrs[.size] as? Int64 ?? 0
            }
            fileFormat = url.pathExtension.uppercased()

            // Capture original state
            originalTitle = title
            originalArtist = artist
            originalAlbum = album
            originalTrackNumber = trackNumber
            originalYear = year
            originalGenre = genre
            originalComment = comment

            // Load artwork
            Task {
                let initialArtwork = await track.loadArtwork()
                await MainActor.run {
                    self.artwork = initialArtwork
                    self.originalArtwork = initialArtwork
                }
            }

        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func save() {
        guard let url = fileURL else {
            errorMessage = "No file URL"
            return
        }

        isLoading = true
        errorMessage = nil

        // Start security-scoped access
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let data = AudioTagData()
        data.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        data.artist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        data.album = album.trimmingCharacters(in: .whitespacesAndNewlines)
        data.trackNumber = trackNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        data.year = year.trimmingCharacters(in: .whitespacesAndNewlines)
        data.genre = genre.trimmingCharacters(in: .whitespacesAndNewlines)
        data.comment = comment.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            try TagLibWrapper.writeTags(data, to: url)

            if artworkChanged {
                var imageData: Data?
                if let artwork {
                    if let tiff = artwork.tiffRepresentation,
                       let bitmap = NSBitmapImageRep(data: tiff)
                    {
                        imageData = bitmap.representation(
                            using: .jpeg,
                            properties: [.compressionFactor: 0.8],
                        )
                    }
                }
                try TagLibWrapper.writeArtwork(imageData, to: url)
            }

            isSaved = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func setArtwork(_ image: NSImage) {
        artwork = image
        artworkChanged = true
    }

    func deleteArtwork() {
        artwork = nil
        artworkChanged = true
    }

    func resetArtwork() {
        artwork = originalArtwork
        artworkChanged = false
    }
}
