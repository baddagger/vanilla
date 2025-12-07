import Foundation

enum SourceType: String, Codable, CaseIterable {
    case file
    case folder
}

struct Source: Identifiable, Codable, Hashable {
    let id: UUID
    let url: URL
    let type: SourceType
    let bookmarkData: Data?
    
    init(url: URL, type: SourceType) {
        self.id = UUID()
        self.url = url
        self.type = type
        
        // Create security bookmark for persistence
        // Ensure we explicitly access the resource to render the bookmark valid
        let isSecured = url.startAccessingSecurityScopedResource()
        defer { if isSecured { url.stopAccessingSecurityScopedResource() } }
        
        var bookmark: Data? = nil
        do {
            bookmark = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        } catch {
            print("Failed to create bookmark for source \(url): \(error)")
        }
        self.bookmarkData = bookmark
    }
    
    func resolvedURL() -> URL? {
        guard let bookmarkData = bookmarkData else { return url }
        var isStale = false
        do {
            let resolved = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
            return resolved
        } catch {
            print("Failed to resolve source bookmark: \(error)")
            return nil
        }
    }
}
