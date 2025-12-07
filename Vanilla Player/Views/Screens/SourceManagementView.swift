import SwiftUI

struct SourceManagementView: View {
    @ObservedObject var libraryManager: LibraryManager

    var body: some View {
        VStack(spacing: 0) {
            // Top Control Bar
            HStack(spacing: 12) {
                Button(action: addFolder) {
                    Label("Add Folder", systemImage: "folder.badge.plus")
                }

                Button(action: addFile) {
                    Label("Add Song", systemImage: "doc.badge.plus")
                }

                Spacer()

                Button {
                    libraryManager.startFullScan()
                } label: {
                    Label("Scan", systemImage: "arrow.clockwise")
                }
                .disabled(libraryManager.isScanning)
                .help("Full Scan")
            }
            .padding(8)

            Divider()

            List {
                ForEach(libraryManager.sources) { source in
                    HStack {
                        Image(systemName: source.type == .folder ? "folder" : "music.note")
                            .frame(width: 20, height: 20)
                            .foregroundColor(.secondary)

                        VStack(alignment: .leading) {
                            Text(source.url.lastPathComponent)
                                .fontWeight(.medium)
                            Text(source.url.deletingLastPathComponent().path)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .truncationMode(.middle)
                        }

                        Spacer()

                        Button {
                            libraryManager.removeSource(source)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .contextMenu {
                        Button("Remove") {
                            libraryManager.removeSource(source)
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
        .overlay {
            if libraryManager.sources.isEmpty {
                ContentUnavailableView(
                    "No Sources",
                    systemImage: "music.note.list",
                    description: Text("Add file or folder sources."),
                )
            }
        }
    }

    private func addFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = NSLocalizedString("Add Source", comment: "Panel Button")

        if panel.runModal() == .OK {
            let urls = panel.urls
            Task {
                for url in urls {
                    await libraryManager.addSource(url: url)
                }
            }
        }
    }

    private func addFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.audio]
        panel.prompt = NSLocalizedString("Add Song", comment: "Panel Button")

        if panel.runModal() == .OK {
            let urls = panel.urls
            Task {
                for url in urls {
                    await libraryManager.addSource(url: url)
                }
            }
        }
    }
}
