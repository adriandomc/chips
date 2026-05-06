import UIKit

enum AppSection: Int, CaseIterable {
    case sequencer
    case mixer
    case synthesizer
    case grid
    case settings
    case help

    var iconName: String {
        switch self {
        case .sequencer: "music.note.list"
        case .mixer: "slider.horizontal.3"
        case .synthesizer: "pianokeys"
        case .grid: "square.grid.4x3.fill"
        case .settings: "gearshape"
        case .help: "questionmark.circle"
        }
    }

    var title: String {
        switch self {
        case .sequencer: "Sequencer"
        case .mixer: "Mixer"
        case .synthesizer: "Synthesizer"
        case .grid: "Grid"
        case .settings: "Settings"
        case .help: "Help"
        }
    }
}
