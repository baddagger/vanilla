import SwiftUI

struct SettingsView: View {
    @AppStorage("spectrumStyle") private var spectrumStyle: SpectrumStyle = .bars

    enum SpectrumStyle: String, CaseIterable, Identifiable {
        case bars
        case segmentedBars = "segmented_bars"
        var id: String { rawValue }

        var localizedName: String {
            switch self {
            case .bars:
                NSLocalizedString(
                    "SPECTRUM_STYLE_BARS",
                    comment: "Label for classic bar visualizer",
                )
            case .segmentedBars:
                NSLocalizedString(
                    "SPECTRUM_STYLE_SEGMENTED",
                    comment: "Label for segmented bar visualizer",
                )
            }
        }
    }

    var body: some View {
        Form {
            Section(NSLocalizedString(
                "VISUALIZER_SETTINGS",
                comment: "Visualizer Settings section title",
            )) {
                Picker(
                    NSLocalizedString("SPECTRUM_STYLE",
                                      comment: "Spectrum Style picker label"),
                    selection: $spectrumStyle,
                ) {
                    ForEach(SpectrumStyle.allCases) { style in
                        Text(style.localizedName).tag(style)
                    }
                }
                .pickerStyle(.inline)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(NSLocalizedString(
            "SETTINGS",
            comment: "Settings window title",
        ))
        .frame(width: 350, height: 150)
    }
}

#Preview {
    SettingsView()
}
