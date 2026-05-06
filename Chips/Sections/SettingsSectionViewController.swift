import ChipsUIKit
import UIKit

final class SettingsSectionViewController: UIViewController {
    private let newButton = ChipsButton()
    private let saveButton = ChipsButton()
    private let loadButton = ChipsButton()
    private let projectName = ChipsTextField()
    private let author = ChipsTextField()
    private let tempoField = ChipsTextField()
    private let tapTempoButton = ChipsButton()
    private let formatButton = ChipsButton()
    private let masterTrackButton = ChipsButton()
    private let stemsButton = ChipsButton()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ChipsTheme.contentBackground

        newButton.title = "NEW"
        saveButton.title = "SAVE"
        loadButton.title = "LOAD"
        for b in [newButton, saveButton, loadButton] {
            b.translatesAutoresizingMaskIntoConstraints = false
        }

        let topRow = UIStackView(arrangedSubviews: [newButton, saveButton, loadButton])
        topRow.axis = .horizontal
        topRow.spacing = 8
        topRow.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(topRow)

        let nameLabel = makeFieldLabel("Project Name")
        let authorLabel = makeFieldLabel("Author")
        projectName.placeholder = "Untitled"
        author.placeholder = "—"

        let tempoLabel = makeFieldLabel("Tempo")
        tempoField.text = "120"
        tempoField.alignment = .center
        let bpmLabel = makeFieldLabel("BPM")
        tapTempoButton.title = "TAP TEMPO"

        let exportTitle = UILabel()
        exportTitle.text = "EXPORT"
        exportTitle.font = ChipsTheme.Font.mono(size: 12, weight: .semibold)
        exportTitle.textColor = ChipsTheme.textPrimary

        let formatLabel = makeFieldLabel("File Format")
        formatButton.title = "MP3"

        masterTrackButton.title = "MASTER TRACK"
        stemsButton.title = "STEMS"

        let exportRow = UIStackView(arrangedSubviews: [masterTrackButton, stemsButton])
        exportRow.axis = .horizontal
        exportRow.spacing = 8

        let formatRow = UIStackView(arrangedSubviews: [formatLabel, formatButton])
        formatRow.axis = .horizontal
        formatRow.spacing = 8
        formatRow.alignment = .center

        let nameRow = makeRow(label: nameLabel, control: projectName)
        let authorRow = makeRow(label: authorLabel, control: author)

        let tempoRow = UIStackView(arrangedSubviews: [tempoLabel, tempoField, bpmLabel, tapTempoButton])
        tempoRow.axis = .horizontal
        tempoRow.spacing = 8
        tempoRow.alignment = .center

        let separator = UIView()
        separator.backgroundColor = ChipsTheme.panelStroke
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.heightAnchor.constraint(equalToConstant: 1).isActive = true

        let stack = UIStackView(arrangedSubviews: [
            topRow,
            nameRow,
            authorRow,
            tempoRow,
            separator,
            exportTitle,
            formatRow,
            UIView(),
            exportRow,
        ])
        stack.axis = .vertical
        stack.spacing = 14
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            tempoField.widthAnchor.constraint(equalToConstant: 60),
        ])
    }

    private func makeFieldLabel(_ text: String) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = ChipsTheme.Font.body(size: 13, weight: .medium)
        l.textColor = ChipsTheme.textPrimary
        return l
    }

    private func makeRow(label: UILabel, control: UIView) -> UIStackView {
        let row = UIStackView(arrangedSubviews: [label, control])
        row.axis = .horizontal
        row.spacing = 12
        row.alignment = .center
        label.widthAnchor.constraint(equalToConstant: 110).isActive = true
        return row
    }
}
