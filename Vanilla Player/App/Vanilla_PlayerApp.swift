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
                Button(NSLocalizedString("ADD_SONG_DOTS", comment: "")) {
                    addFile()
                }
                .keyboardShortcut("O", modifiers: [.command])

                Button(NSLocalizedString("ADD_FOLDER_DOTS", comment: "")) {
                    addFolder()
                }
                .keyboardShortcut("O", modifiers: [.command, .shift])

                Divider()

                Button(NSLocalizedString("MANAGE_SOURCES_DOTS", comment: "")) {
                    openWindow(id: "source-management")
                }
                .keyboardShortcut("S", modifiers: [.command, .control])

                Divider()

                Button(NSLocalizedString("TRACK_DETAILS", comment: "")) {
                    if let track = playerViewModel.currentTrack {
                        openWindow(id: "track-info", value: track)
                    }
                }
                .keyboardShortcut("I", modifiers: [.command])
            }

            // Add Check for Updates menu item
            CommandGroup(after: .appInfo) {
                Button(NSLocalizedString("CHECK_FOR_UPDATES_DOTS", comment: "Menu item")) {
                    updaterController.checkForUpdates(nil)
                }
            }
        }

        Window(
            NSLocalizedString("SOURCE_MANAGEMENT", comment: ""),
            id: "source-management",
        ) {
            SourceManagementView(libraryManager: playerViewModel.libraryManager)
        }
        .defaultSize(width: 400, height: 500)

        WindowGroup(
            NSLocalizedString("TRACK_DETAILS", comment: ""),
            id: "track-info",
            for: Track.self,
        ) { $track in
            if let track {
                TrackInfoView(track: track)
                    .environmentObject(playerViewModel)
            }
        }
        .defaultSize(width: 450, height: 600)

        #if os(macOS)
            Settings {
                SettingsView()
            }
        #endif
    }

    private func addFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = NSLocalizedString("ADD_SOURCE", comment: "")

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
        panel.prompt = NSLocalizedString("ADD_SONG", comment: "")

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
