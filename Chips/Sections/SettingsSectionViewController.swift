import ChipsCore
import ChipsUIKit
import UIKit

final class SettingsSectionViewController: UIViewController {
    private let controller: ProjectController

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
    private let aboutButton = ChipsButton()

    init(controller: ProjectController) {
        self.controller = controller
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("SettingsSectionViewController no soporta NSCoder")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ChipsTheme.contentBackground
        configureButtons()
        configureFields()
        layoutContent()
        wireActions()
        projectName.text = controller.graph.name == "Untitled" ? "" : controller.graph.name
        author.text = controller.graph.author
        tempoField.text = String(Int(controller.transport.tempoBpm))
    }

    private func configureButtons() {
        newButton.title = String(localized: "settings.button.new")
        saveButton.title = String(localized: "settings.button.save")
        loadButton.title = String(localized: "settings.button.load")
        tapTempoButton.title = String(localized: "settings.button.tap_tempo")
        formatButton.title = String(localized: "settings.button.wav")
        mainTrackButton.title = String(localized: "settings.button.master_track")
        stemsButton.title = String(localized: "settings.button.stems")
        aboutButton.title = String(localized: "settings.button.about")
    }

    private func configureFields() {
        projectName.placeholder = String(localized: "settings.placeholder.untitled")
        author.placeholder = "—"
        tempoField.alignment = .center
    }

    private func wireActions() {
        newButton.addTarget(self, action: #selector(newTapped), for: .touchUpInside)
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        loadButton.addTarget(self, action: #selector(loadTapped), for: .touchUpInside)
        mainTrackButton.addTarget(self, action: #selector(exportMainTrackTapped), for: .touchUpInside)
        stemsButton.addTarget(self, action: #selector(stemsTapped), for: .touchUpInside)
        aboutButton.addTarget(self, action: #selector(aboutTapped), for: .touchUpInside)
    }

    private func layoutContent() {
        let topRow = makeRow(buttons: [newButton, saveButton, loadButton])
        let nameRow = makeFieldRow(label: String(localized: "settings.label.project_name"), control: projectName)
        let authorRow = makeFieldRow(label: String(localized: "settings.label.author"), control: author)
        let tempoRow = makeTempoRow()
        let separator = makeSeparator()
        let exportTitle = makeExportTitle()
        let formatRow = makeFormatRow()
        let exportRow = makeRow(buttons: [mainTrackButton, stemsButton])

        let aboutSeparator = makeSeparator()
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
            aboutSeparator,
            aboutButton,
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
        let tempoLabel = makeFieldLabel(String(localized: "settings.label.tempo"))
        let bpmLabel = makeFieldLabel(String(localized: "settings.label.bpm"))
        let row = UIStackView(arrangedSubviews: [tempoLabel, tempoField, bpmLabel, tapTempoButton])
        row.axis = .horizontal
        row.spacing = 8
        row.alignment = .center
        return row
    }

    private func makeFormatRow() -> UIStackView {
        let formatLabel = makeFieldLabel(String(localized: "settings.label.file_format"))
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
        label.text = String(localized: "settings.label.export")
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

    // MARK: Acciones

    @objc private func newTapped() {
        do {
            try controller.apply(graph: ProjectController.defaultGraph())
            projectName.text = ""
            author.text = ""
            tempoField.text = "120"
            showAlert(
                title: String(localized: "settings.alert.new_project_title"),
                message: String(localized: "settings.alert.new_project_message")
            )
        } catch {
            showAlert(title: String(localized: "common.error"), message: "\(error)")
        }
    }

    @objc private func saveTapped() {
        let name = (projectName.text?.isEmpty == false) ? projectName.text! : "Untitled"
        let graph = controller.currentGraph(name: name, author: author.text ?? "")
        do {
            let data = try ProjectStorage.encode(graph)
            let url = documentsDirectory().appendingPathComponent("\(name).\(ProjectStorage.fileExtension)")
            try data.write(to: url, options: .atomic)
            showAlert(title: String(localized: "settings.alert.save_success"), message: url.lastPathComponent)
        } catch {
            showAlert(title: String(localized: "settings.alert.save_error"), message: "\(error)")
        }
    }

    @objc private func loadTapped() {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: documentsDirectory(),
            includingPropertiesForKeys: nil
        )) ?? []
        let chipsFiles = urls.filter { $0.pathExtension == ProjectStorage.fileExtension }
        guard !chipsFiles.isEmpty else {
            let format = String(localized: "settings.alert.no_projects_message_format")
            showAlert(
                title: String(localized: "settings.alert.no_projects_title"),
                message: String(format: format, ProjectStorage.fileExtension)
            )
            return
        }
        let alert = UIAlertController(
            title: String(localized: "settings.alert.load_project"),
            message: nil,
            preferredStyle: .actionSheet
        )
        for url in chipsFiles {
            alert.addAction(UIAlertAction(title: url.lastPathComponent, style: .default) { [weak self] _ in
                self?.loadProject(from: url)
            })
        }
        alert.addAction(UIAlertAction(title: String(localized: "common.cancel"), style: .cancel))
        present(alert, animated: true)
    }

    private func loadProject(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let graph = try ProjectStorage.decodeProject(data)
            try controller.apply(graph: graph)
            projectName.text = graph.name
            author.text = graph.author
            tempoField.text = String(Int(graph.tempoBpm))
        } catch {
            showAlert(title: String(localized: "settings.alert.load_error"), message: "\(error)")
        }
    }

    @objc private func exportMainTrackTapped() {
        let name = (projectName.text?.isEmpty == false) ? projectName.text! : "main"
        let url = documentsDirectory().appendingPathComponent("\(name).wav")
        do {
            try controller.exportWav(to: url, seconds: 8)
            let format = String(localized: "settings.alert.export_main_message_format")
            showAlert(
                title: String(localized: "settings.alert.export_main_title"),
                message: String(format: format, url.lastPathComponent)
            )
        } catch {
            showAlert(title: String(localized: "settings.alert.export_error"), message: "\(error)")
        }
    }

    @objc private func stemsTapped() {
        let typed = projectName.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let baseName = typed.isEmpty ? "Untitled" : typed
        do {
            let urls = try controller.exportStems(directoryURL: documentsDirectory(), baseName: baseName, seconds: 8)
            if urls.isEmpty {
                showAlert(
                    title: String(localized: "settings.alert.stems_title"),
                    message: String(localized: "settings.alert.stems_empty_message")
                )
                return
            }
            let format = String(localized: "settings.alert.stems_done_message_format")
            showAlert(
                title: String(localized: "settings.alert.stems_title"),
                message: String(format: format, urls.count)
            )
        } catch {
            showAlert(title: String(localized: "settings.alert.export_error"), message: "\(error)")
        }
    }

    @objc private func aboutTapped() {
        let about = AboutViewController()
        let nav = UINavigationController(rootViewController: about)
        nav.modalPresentationStyle = .formSheet
        present(nav, animated: true)
    }

    private func documentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: String(localized: "common.ok"), style: .default))
        present(alert, animated: true)
    }
}
