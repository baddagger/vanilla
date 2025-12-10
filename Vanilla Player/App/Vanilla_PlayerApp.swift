import Sparkle
import SwiftUI

@main
struct Vanilla_PlayerApp: App {
    @StateObject private var playerViewModel = PlayerViewModel()
    @Environment(\.openWindow) var openWindow
    @Environment(\.scenePhase) private var scenePhase

    // Sparkle updater controller
    private let updaterController: SPUStandardUpdaterController

    init() {
        // Initialize Sparkle updater - starts automatically and checks for user permissions on
        // first run
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil,
        )
    }

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
                        for: NSWindow.willCloseNotification,
                    ),
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
                Button(NSLocalizedString("Add Song...", comment: "")) {
                    addFile()
                }
                .keyboardShortcut("O", modifiers: [.command])

                Button(NSLocalizedString("Add Folder...", comment: "")) {
                    addFolder()
                }
                .keyboardShortcut("O", modifiers: [.command, .shift])

                Divider()

                Button(NSLocalizedString("Manage Sources...", comment: "")) {
                    openWindow(id: "source-management")
                }
                .keyboardShortcut("S", modifiers: [.command, .control])
            }

            // Remove Edit Menu
            CommandGroup(replacing: .undoRedo) {}
            CommandGroup(replacing: .pasteboard) {}

            // Add Check for Updates menu item
            CommandGroup(after: .appInfo) {
                Button(NSLocalizedString("Check for Updates...", comment: "Menu item")) {
                    updaterController.checkForUpdates(nil)
                }
            }
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
