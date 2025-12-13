import SwiftUI
import UniformTypeIdentifiers

struct VinylNowPlayingView: View {
    @EnvironmentObject var viewModel: PlayerViewModel
    @State var playbackProgress: CGFloat = -1

    var body: some View {
        ZStack {
            GeometryReader { geometry in
                let containerHeight = geometry.size.height

                let vinylSize = containerHeight * 0.7

                let buttonSize = vinylSize * 0.15

                VStack(alignment: .leading) {
                    ZStack {
                        Vinyl(vinylSize: vinylSize)

                        ArcText(
                            text: "VOLUME",
                            radius: vinylSize * 0.546,
                            startAngle: .degrees(-36),
                            spacing: 1.6,
                            configure: { view in
                                view.font(.system(size: 7))
                                    .foregroundColor(
                                        Color(hex: "#c0a06c").opacity(0.6),
                                    )
                            },
                        )
                        .frame(width: vinylSize, height: vinylSize)

                        KnobView(
                            buttonSize: buttonSize,
                            startAngle: -180,
                            endAngle: 0,
                            progress: Binding(
                                get: { Double(viewModel.volume) },
                                set: { viewModel.volume = Float($0) },
                            ),
                        )
                        .offset(
                            x: -vinylSize / 2 + buttonSize / 2,
                            y: -vinylSize / 2 + buttonSize / 2,
                        )

                        ArcText(
                            text: "BASS",
                            radius: vinylSize * 0.546,
                            startAngle: .degrees(-149),
                            spacing: 1.6,
                            configure: { view in
                                view.font(.system(size: 7))
                                    .foregroundColor(
                                        Color(hex: "#c0a06c").opacity(0.6),
                                    )
                            },
                        )
                        .frame(width: vinylSize, height: vinylSize)

                        KnobView(
                            buttonSize: buttonSize,
                            startAngle: -180,
                            endAngle: 0,
                            progress: Binding(
                                get: { Double(viewModel.bass + 1) / 2 }, // Map -1...1 to 0...1
                                set: { viewModel.bass = Float($0 * 2 - 1) }, // Map 0...1 to -1...1
                            ),
                        )
                        .offset(
                            x: -vinylSize / 2 + buttonSize / 2,
                            y: vinylSize / 2 - buttonSize / 2,
                        )
                        .onTapGesture(count: 2) {
                            withAnimation {
                                viewModel.bass = 0
                            }
                        }

                        Image("armLock")
                            .resizable()
                            .frame(
                                width: buttonSize * 0.6,
                                height: buttonSize * 1.1,
                            )
                            .cornerRadius(buttonSize * 1.1)
                            .shadow(
                                color: Color.black.opacity(0.6),
                                radius: 1,
                                x: -0.5,
                                y: 0.5,
                            )
                            .rotationEffect(.degrees(30))
                            .offset(
                                x: vinylSize / 2 + buttonSize * 0.02,
                                y: vinylSize / 2 - buttonSize * 0.8,
                            )

                        let tonearmHeight = vinylSize * 0.85

                        TonearmView(
                            startAngle: -11,
                            endAngle: 13,
                            idleAngle: -26,
                            playbackProgress: Binding(
                                get: {
                                    viewModel.duration > 0
                                        ? Double(viewModel.currentTime / viewModel.duration)
                                        : -1.0
                                },
                                set: { newValue in
                                    let newTime = newValue * viewModel.duration
                                    viewModel.seek(to: newTime)
                                },
                            ),
                        )
                        .frame(height: tonearmHeight)
                        .offset(x: tonearmHeight * 0.52, y: -tonearmHeight / 12)
                    }
                    .frame(width: vinylSize, height: vinylSize)

                    Spacer()
                        .frame(height: 48)

                    Controls()
                        .frame(width: vinylSize * 1.1)
                        .frame(maxHeight: .infinity)
                }
            }
        }
    }
}

struct Vinyl: View {
    let vinylSize: CGFloat
    @EnvironmentObject var viewModel: PlayerViewModel

    var body: some View {
        ZStack {
            let coverSize = vinylSize * 0.34

            Spacer()
                .background(Color.black)
                .frame(width: vinylSize - 1, height: vinylSize - 1)
                .cornerRadius(vinylSize / 2)
                .shadow(color: Color.black.opacity(0.8), radius: 8, x: -5, y: 5)

            Image("vinylLabelArea")
                .resizable()
                .frame(width: coverSize, height: coverSize)

            // GPU-accelerated rotation using CABasicAnimation
            RotatingVinylCover(
                track: viewModel.currentTrack,
                isSpinning: viewModel.isPlaying && viewModel.isWindowVisible,
                rpm: 2.5, // Revolutions per minute (slow vinyl spin)
            )
            .frame(width: coverSize, height: coverSize)
            .clipShape(Circle())

            Image("vinyl")
                .resizable()
                .aspectRatio(1, contentMode: .fit)
                .onDrop(of: [UTType.fileURL.identifier], isTargeted: nil) { providers in
                    for provider in providers {
                        // Attempt to load as URL directly
                        _ = provider.loadObject(ofClass: URL.self) { url, _ in
                            if let url {
                                print("Dropped URL: \(url)")
                                DispatchQueue.main.async {
                                    viewModel.addFiles(urls: [url])
                                }
                            } else {
                                // Fallback: Load as item (sometimes needed for file URLs)
                                provider.loadItem(
                                    forTypeIdentifier: UTType.fileURL
                                        .identifier,
                                    options: nil,
                                ) { item, _ in
                                    if let data = item as? Data,
                                       let url = URL(
                                           dataRepresentation: data,
                                           relativeTo: nil,
                                       )
                                    {
                                        print("Dropped URL (data): \(url)")
                                        DispatchQueue.main.async {
                                            viewModel.addFiles(urls: [url])
                                        }
                                    } else if let url = item as? URL {
                                        print("Dropped URL (item): \(url)")
                                        DispatchQueue.main.async {
                                            viewModel.addFiles(urls: [url])
                                        }
                                    }
                                }
                            }
                        }
                    }
                    return true
                }

            Image("spindleDot")
                .resizable()
                .frame(width: vinylSize * 0.036, height: vinylSize * 0.036)
                .shadow(color: Color.black.opacity(0.6), radius: 1, x: -1, y: 1)
        }
    }
}

struct Controls: View {
    @EnvironmentObject var viewModel: PlayerViewModel

    var body: some View {
        let buttonSize = 36.0
        let buttonSizeLarge = 96.0

        HStack(spacing: 32) {
            Button(action: {
                viewModel.toggleShuffle()
            }) {
                ZStack {
                    Image("buttonGold")
                        .resizable()
                        .frame(width: buttonSize, height: buttonSize)

                    Image(systemName: "shuffle")
                        .font(.system(size: buttonSize * 0.4, weight: .bold))
                        .foregroundColor(
                            viewModel.isShuffleEnabled
                                ? Color.black.opacity(0.8)
                                : Color.black.opacity(0.4),
                        )
                }
            }

            Button(action: {
                viewModel.previousTrack()
            }) {
                Image("buttonSkip")
                    .resizable()
                    .rotationEffect(.degrees(180))
                    .frame(width: buttonSize * 1.8, height: buttonSize * 0.9)
            }

            Button(action: {
                viewModel.playPause()
            }) {
                ZStack {
                    Image("buttonGold")
                        .resizable()
                        .frame(width: buttonSizeLarge, height: buttonSizeLarge)

                    Image(viewModel.isPlaying ? "iconPause" : "iconPlay") // Play/pause icon toggle
                        .resizable()
                        .frame(
                            width: buttonSizeLarge * 0.7,
                            height: buttonSizeLarge * 0.7,
                        )
                }
            }

            Button(action: {
                viewModel.nextTrack()
            }) {
                Image("buttonSkip")
                    .resizable()
                    .frame(width: buttonSize * 1.8, height: buttonSize * 0.9)
            }

            Button(action: {
                viewModel.toggleRepeat()
            }) {
                ZStack {
                    Image("buttonGold")
                        .resizable()
                        .frame(width: buttonSize, height: buttonSize)

                    let systemName = switch viewModel.repeatMode {
                    case .one: "repeat.1"
                    default: "repeat"
                    }

                    Image(systemName: systemName)
                        .font(.system(size: buttonSize * 0.4, weight: .bold))
                        .foregroundColor(
                            viewModel.repeatMode != .off
                                ? Color.black.opacity(0.8)
                                : Color.black.opacity(0.4),
                        )
                }
            }
        }
        .buttonStyle(.plain)
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .cornerRadius(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "#21160f").opacity(0.36),
                            Color(hex: "#21160f").opacity(0.52),
                        ],
                        startPoint: .top,
                        endPoint: .bottom,
                    ),
                )
                .shadow(
                    color: Color.black.opacity(0.8),
                    radius: 10,
                    x: -4,
                    y: 4,
                ),
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.12), lineWidth: 2),
        )
    }
}

struct DebugAnchorView: View {
    let anchor: UnitPoint

    var body: some View {
        GeometryReader { geometry in
            Circle()
                .fill(Color.red)
                .frame(width: 10, height: 10)
                .position(
                    x: geometry.size.width * anchor.x,
                    y: geometry.size.height * anchor.y,
                )
        }
    }
}

extension URL: Identifiable {
    public var id: String { absoluteString }
}

#Preview {
    VinylNowPlayingView()
        .environmentObject(PlayerViewModel())
        .padding()
}
