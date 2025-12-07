import SwiftUI

@main
struct Vanilla_PlayerApp: App {
    @StateObject private var playerViewModel = PlayerViewModel()
    @Environment(\.openWindow) var openWindow
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(playerViewModel)
                .onChange(of: scenePhase) { newPhase in
                    let isActive = newPhase == .active
                    playerViewModel.setAppActive(isActive)
                }
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: NSWindow.willCloseNotification
                    )
                ) { _ in
                    playerViewModel.savePlaybackState()
                }
                .onOpenURL(perform: { url in
                    playerViewModel.addFiles(urls: [url])
                })
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1200, height: 800)
        .handlesExternalEvents(matching: ["*"])
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Add Song...") {
                    addFile()
                }
                .keyboardShortcut("O", modifiers: [.command])

                Button("Add Folder...") {
                    addFolder()
                }
                .keyboardShortcut("O", modifiers: [.command, .shift])

                Divider()

                Button("Manage Sources...") {
                    openWindow(id: "source-management")
                }
                .keyboardShortcut("S", modifiers: [.command, .control])
            }

            // Remove Edit Menu
            CommandGroup(replacing: .undoRedo) {}
            CommandGroup(replacing: .pasteboard) {}
        }

        Window("Source Management", id: "source-management") {
            SourceManagementView(libraryManager: playerViewModel.libraryManager)
        }
        .defaultSize(width: 400, height: 500)
    }

    private func addFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = "Add Source"

        if panel.runModal() == .OK {
            let urls = panel.urls
            Task {
                for url in urls {
                    await playerViewModel.libraryManager.addSource(url: url)
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
        panel.prompt = "Add Song"

        if panel.runModal() == .OK {
            let urls = panel.urls
            Task {
                for url in urls {
                    await playerViewModel.libraryManager.addSource(url: url)
                }
            }
        }
    }
}
