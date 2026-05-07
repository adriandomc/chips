import ChipsCore
import ChipsEngine
import ChipsUIKit
import UIKit

/// Panel auto-generado a partir de la metadata `ParameterSpec` que el módulo
/// expone vía la C ABI. Se usa como fallback cuando un nodo no tiene un panel
/// custom registrado en `InstrumentUIRegistry`.
///
/// La idea: cualquier módulo nuevo es **utilizable inmediatamente** sin
/// escribir código UI específico — los knobs se generan desde las specs.
final class GenericInstrumentPanelViewController: UIViewController {
    private let ref: NodeRef
    private let controller: ProjectController
    private let titleLabel = UILabel()

    init(ref: NodeRef, controller: ProjectController) {
        self.ref = ref
        self.controller = controller
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("GenericInstrumentPanelViewController no soporta NSCoder")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ChipsTheme.contentBackground
        configureTitle()
        layoutKnobs()
    }

    private func configureTitle() {
        let typeId = controller.graph.node(withRef: ref)?.typeId ?? "unknown"
        let displayName = controller.graph.node(withRef: ref)?.displayName ?? typeId
        titleLabel.text = "\(displayName) (\(typeId))"
        titleLabel.font = ChipsTheme.Font.mono(size: 13, weight: .semibold)
        titleLabel.textColor = ChipsTheme.textPrimary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
        ])
    }

    private func layoutKnobs() {
        guard let chipsId = controller.chipsNodeId(for: ref) else {
            return
        }
        let specs = controller.host.engine.parameterSpecs(of: chipsId)
        guard !specs.isEmpty else {
            showEmptyMessage()
            return
        }
        let columns = 4
        let grid = UIStackView()
        grid.axis = .vertical
        grid.spacing = 12
        grid.translatesAutoresizingMaskIntoConstraints = false

        for chunk in specs.chunked(into: columns) {
            let row = UIStackView()
            row.axis = .horizontal
            row.distribution = .fillEqually
            row.alignment = .top
            row.spacing = 8
            for spec in chunk {
                row.addArrangedSubview(makeKnob(for: spec))
            }
            for _ in chunk.count ..< columns {
                row.addArrangedSubview(UIView())
            }
            grid.addArrangedSubview(row)
        }

        view.addSubview(grid)
        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            grid.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            grid.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
        ])
    }

    private func makeKnob(for spec: ParameterSpec) -> UIView {
        let knob = ChipsKnob()
        knob.label = spec.name
        knob.minValue = spec.minValue
        knob.maxValue = spec.maxValue
        let initial = controller.parameter(of: ref, name: spec.name) ?? spec.defaultValue
        knob.value = initial
        knob.translatesAutoresizingMaskIntoConstraints = false
        knob.heightAnchor.constraint(equalToConstant: 84).isActive = true
        let action = UIAction { [weak self, weak knob] _ in
            guard let self, let knob else { return }
            controller.setParameter(of: ref, paramName: spec.name, value: knob.value)
        }
        knob.addAction(action, for: .valueChanged)
        return knob
    }

    private func showEmptyMessage() {
        let label = UILabel()
        label.text = "Este módulo no expone parámetros."
        label.font = ChipsTheme.Font.body(size: 13)
        label.textColor = ChipsTheme.textSecondary
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
