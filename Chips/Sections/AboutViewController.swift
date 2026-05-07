import ChipsUIKit
import UIKit

/// Pantalla "About" presentada modal desde Settings. Concentra:
/// - identidad de la app (nombre + versión + build),
/// - links legales (Privacy Policy, Terms) — ahora placeholder,
/// - "Restore Purchases" (Apple lo exige aunque la app sea paid-up-front),
/// - créditos de open source.
///
/// Diseño: misma paleta cálida del resto del app — fondo `contentBackground`,
/// tipografía mono para identidad, body para legales. Stack vertical simple
/// con divisores tipo strokes oscuros sutiles.
final class AboutViewController: UIViewController {
    private let scroll = UIScrollView()
    private let stack = UIStackView()
    private let restoreButton = ChipsButton()
    private var restoreInFlight = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ChipsTheme.contentBackground
        configureNavigation()
        layoutContent()
    }

    private func configureNavigation() {
        title = "About"
        navigationController?.navigationBar.titleTextAttributes = [
            .font: ChipsTheme.Font.mono(size: 14, weight: .semibold),
            .foregroundColor: ChipsTheme.textPrimary,
        ]
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(closeTapped)
        )
    }

    private func layoutContent() {
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)

        stack.axis = .vertical
        stack.spacing = 14
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)

        stack.addArrangedSubview(makeIdentityBlock())
        stack.addArrangedSubview(makeSeparator())
        stack.addArrangedSubview(makeLegalRow(title: "Privacy Policy", action: #selector(privacyTapped)))
        stack.addArrangedSubview(makeLegalRow(title: "Terms of Service", action: #selector(termsTapped)))
        stack.addArrangedSubview(makeLegalRow(title: "Open Source Licenses", action: #selector(licensesTapped)))
        stack.addArrangedSubview(makeSeparator())
        stack.addArrangedSubview(makeRestoreBlock())
        stack.addArrangedSubview(makeFooter())

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -24),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -48),
        ])
    }

    private func makeIdentityBlock() -> UIView {
        let container = UIStackView()
        container.axis = .vertical
        container.spacing = 6
        container.alignment = .leading

        let nameLabel = UILabel()
        nameLabel.text = "Chips"
        nameLabel.font = ChipsTheme.Font.mono(size: 32, weight: .bold)
        nameLabel.textColor = ChipsTheme.textPrimary

        let versionLabel = UILabel()
        versionLabel.text = "Version \(Self.versionString) (\(Self.buildString))"
        versionLabel.font = ChipsTheme.Font.mono(size: 13)
        versionLabel.textColor = ChipsTheme.textSecondary

        let descriptionLabel = UILabel()
        descriptionLabel.text = "Modular DAW para iOS."
        descriptionLabel.font = ChipsTheme.Font.body(size: 13)
        descriptionLabel.textColor = ChipsTheme.textSecondary
        descriptionLabel.numberOfLines = 0

        container.addArrangedSubview(nameLabel)
        container.addArrangedSubview(versionLabel)
        container.addArrangedSubview(descriptionLabel)
        return container
    }

    private func makeSeparator() -> UIView {
        let separator = UIView()
        separator.backgroundColor = ChipsTheme.panelStroke
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return separator
    }

    private func makeLegalRow(title: String, action: Selector) -> UIView {
        let button = ChipsButton()
        button.title = title
        button.contentInsets = .init(top: 10, left: 12, bottom: 10, right: 12)
        button.titleFont = ChipsTheme.Font.body(size: 14, weight: .medium)
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    private func makeRestoreBlock() -> UIView {
        let container = UIStackView()
        container.axis = .vertical
        container.spacing = 8
        container.alignment = .fill

        let title = UILabel()
        title.text = "PURCHASES"
        title.font = ChipsTheme.Font.mono(size: 11, weight: .semibold)
        title.textColor = ChipsTheme.textSecondary

        restoreButton.title = "Restore Purchases"
        restoreButton.contentInsets = .init(top: 10, left: 12, bottom: 10, right: 12)
        restoreButton.titleFont = ChipsTheme.Font.body(size: 14, weight: .medium)
        restoreButton.addTarget(self, action: #selector(restoreTapped), for: .touchUpInside)

        let hint = UILabel()
        hint.text = "Chips es una compra única. Restore re-sincroniza tu cuenta de App Store."
        hint.font = ChipsTheme.Font.body(size: 11)
        hint.textColor = ChipsTheme.textSecondary
        hint.numberOfLines = 0

        container.addArrangedSubview(title)
        container.addArrangedSubview(restoreButton)
        container.addArrangedSubview(hint)
        return container
    }

    private func makeFooter() -> UIView {
        let label = UILabel()
        label.text = "© 2026 Adrián Domingo Carballal."
        label.font = ChipsTheme.Font.mono(size: 11)
        label.textColor = ChipsTheme.textSecondary
        label.textAlignment = .left
        return label
    }

    // MARK: Actions

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    @objc private func privacyTapped() {
        showPlaceholder(title: "Privacy Policy")
    }

    @objc private func termsTapped() {
        showPlaceholder(title: "Terms of Service")
    }

    @objc private func licensesTapped() {
        showPlaceholder(title: "Open Source Licenses")
    }

    @objc private func restoreTapped() {
        guard !restoreInFlight else { return }
        restoreInFlight = true
        restoreButton.isEnabled = false
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                restoreInFlight = false
                restoreButton.isEnabled = true
            }
            do {
                try await EntitlementManager.shared.restorePurchases()
                showAlert(title: "Restore", message: "Compras sincronizadas con tu cuenta de App Store.")
            } catch {
                showAlert(title: "Restore", message: "No se pudo sincronizar: \(error.localizedDescription)")
            }
        }
    }

    private func showPlaceholder(title: String) {
        showAlert(title: title, message: "URL pendiente. Se publicará junto con el lanzamiento en App Store.")
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    // MARK: Version helpers

    private static var versionString: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    private static var buildString: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    }
}
