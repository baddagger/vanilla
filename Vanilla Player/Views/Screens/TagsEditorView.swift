import SwiftUI

struct TagsEditorView: View {
    @EnvironmentObject var playerViewModel: PlayerViewModel
    @StateObject private var viewModel: TagsEditorViewModel
    @Environment(\.dismiss) private var dismiss

    init(track: Track) {
        _viewModel = StateObject(wrappedValue: TagsEditorViewModel(track: track))
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 20) {
                Grid(alignment: .trailing, horizontalSpacing: 15, verticalSpacing: 12) {
                    // Main Metadata
                    GridRow {
                        Text(NSLocalizedString("TAGS_EDITOR_TITLE", comment: "Label"))
                        TextField("", text: $viewModel.title)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled(true)
                    }
                    GridRow {
                        Text(NSLocalizedString("TAGS_EDITOR_ARTIST", comment: "Label"))
                        TextField("", text: $viewModel.artist)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled(true)
                    }
                    GridRow {
                        Text(NSLocalizedString("TAGS_EDITOR_ALBUM", comment: "Label"))
                        TextField("", text: $viewModel.album)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled(true)
                    }

                    Divider()

                    // Secondary Metadata
                    GridRow {
                        Text(NSLocalizedString("TAGS_EDITOR_TRACK_NUMBER", comment: "Label"))
                        TextField("", text: $viewModel.trackNumber)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled(true)
                    }
                    GridRow {
                        Text(NSLocalizedString("TAGS_EDITOR_YEAR", comment: "Label"))
                        TextField("", text: $viewModel.year)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled(true)
                    }
                    GridRow {
                        Text(NSLocalizedString("TAGS_EDITOR_GENRE", comment: "Label"))
                        TextField("", text: $viewModel.genre)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled(true)
                    }

                    Divider()

                    // Comment (Spanning row)
                    GridRow {
                        Text(NSLocalizedString("TAGS_EDITOR_COMMENT", comment: "Label"))
                        TextField("", text: $viewModel.comment, axis: .vertical)
                            .lineLimit(3 ... 6)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled(true)
                    }
                }
                .padding([.top, .horizontal])

                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }

                Spacer()
            }
        }
        .navigationTitle(NSLocalizedString("TAGS_EDITOR_WINDOW_TITLE", comment: "Navigation Title"))
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(NSLocalizedString("TAGS_EDITOR_SAVE_BUTTON", comment: "Button")) {
                    viewModel.save()
                    if viewModel.isSaved {
                        // Refresh the track in library
                        Task {
                            await playerViewModel.libraryManager.refreshTrack(viewModel.track)
                        }
                        dismiss()
                    }
                }
                .disabled(viewModel.isLoading || !viewModel.hasChanges)
            }
        }
        .frame(minWidth: 400, minHeight: 400)
    }
}

struct TagsEditorWrapper: View {
    @EnvironmentObject var playerViewModel: PlayerViewModel

    var body: some View {
        if let track = playerViewModel.trackToEdit {
            TagsEditorView(track: track)
                .environmentObject(playerViewModel)
                .id(track.id) // Force recreate view and viewModel when track changes
                .onDisappear {
                    playerViewModel.trackToEdit = nil
                }
        } else {
            ContentUnavailableView(
                NSLocalizedString("TAGS_EDITOR_NO_TRACK_TITLE", comment: "Empty State Title"),
                systemImage: "music.note",
                description: Text(NSLocalizedString(
                    "TAGS_EDITOR_NO_TRACK_DESCRIPTION",
                    comment: "Empty State Description",
                )),
            )
        }
    }
}
