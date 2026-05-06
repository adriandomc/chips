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
    private let mainTrackButton = ChipsButton()
    private let stemsButton = ChipsButton()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ChipsTheme.contentBackground
        configureButtons()
        configureFields()
        layoutContent()
    }

    private func configureButtons() {
        newButton.title = "NEW"
        saveButton.title = "SAVE"
        loadButton.title = "LOAD"
        tapTempoButton.title = "TAP TEMPO"
        formatButton.title = "MP3"
        mainTrackButton.title = "MASTER TRACK"
        stemsButton.title = "STEMS"
    }

    private func configureFields() {
        projectName.placeholder = "Untitled"
        author.placeholder = "—"
        tempoField.text = "120"
        tempoField.alignment = .center
    }

    private func layoutContent() {
        let topRow = makeRow(buttons: [newButton, saveButton, loadButton])
        let nameRow = makeFieldRow(label: "Project Name", control: projectName)
        let authorRow = makeFieldRow(label: "Author", control: author)
        let tempoRow = makeTempoRow()
        let separator = makeSeparator()
        let exportTitle = makeExportTitle()
        let formatRow = makeFormatRow()
        let exportRow = makeRow(buttons: [mainTrackButton, stemsButton])

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

    private func makeRow(buttons: [ChipsButton]) -> UIStackView {
        let row = UIStackView(arrangedSubviews: buttons)
        row.axis = .horizontal
        row.spacing = 8
        return row
    }

    private func makeFieldRow(label: String, control: UIView) -> UIStackView {
        let row = UIStackView(arrangedSubviews: [makeFieldLabel(label), control])
        row.axis = .horizontal
        row.spacing = 12
        row.alignment = .center
        if let firstLabel = row.arrangedSubviews.first {
            firstLabel.widthAnchor.constraint(equalToConstant: 110).isActive = true
        }
        return row
    }

    private func makeTempoRow() -> UIStackView {
        let tempoLabel = makeFieldLabel("Tempo")
        let bpmLabel = makeFieldLabel("BPM")
        let row = UIStackView(arrangedSubviews: [tempoLabel, tempoField, bpmLabel, tapTempoButton])
        row.axis = .horizontal
        row.spacing = 8
        row.alignment = .center
        return row
    }

    private func makeFormatRow() -> UIStackView {
        let formatLabel = makeFieldLabel("File Format")
        let row = UIStackView(arrangedSubviews: [formatLabel, formatButton])
        row.axis = .horizontal
        row.spacing = 8
        row.alignment = .center
        return row
    }

    private func makeSeparator() -> UIView {
        let separator = UIView()
        separator.backgroundColor = ChipsTheme.panelStroke
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return separator
    }

    private func makeExportTitle() -> UILabel {
        let label = UILabel()
        label.text = "EXPORT"
        label.font = ChipsTheme.Font.mono(size: 12, weight: .semibold)
        label.textColor = ChipsTheme.textPrimary
        return label
    }

    private func makeFieldLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = ChipsTheme.Font.body(size: 13, weight: .medium)
        label.textColor = ChipsTheme.textPrimary
        return label
    }
}
