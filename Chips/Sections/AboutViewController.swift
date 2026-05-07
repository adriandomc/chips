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
        title = String(localized: "about.title")
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
        stack.addArrangedSubview(makeLegalRow(
            title: String(localized: "about.privacy_policy"),
            action: #selector(privacyTapped)
        ))
        stack.addArrangedSubview(makeLegalRow(
            title: String(localized: "about.terms"),
            action: #selector(termsTapped)
        ))
        stack.addArrangedSubview(makeLegalRow(
            title: String(localized: "about.licenses"),
            action: #selector(licensesTapped)
        ))
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

        let versionFormat = String(localized: "about.version_format")
        let versionLabel = UILabel()
        versionLabel.text = String(format: versionFormat, Self.versionString, Self.buildString)
        versionLabel.font = ChipsTheme.Font.mono(size: 13)
        versionLabel.textColor = ChipsTheme.textSecondary

        let descriptionLabel = UILabel()
        descriptionLabel.text = String(localized: "about.description")
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
        title.text = String(localized: "about.purchases_label")
        title.font = ChipsTheme.Font.mono(size: 11, weight: .semibold)
        title.textColor = ChipsTheme.textSecondary

        restoreButton.title = String(localized: "about.restore_button")
        restoreButton.contentInsets = .init(top: 10, left: 12, bottom: 10, right: 12)
        restoreButton.titleFont = ChipsTheme.Font.body(size: 14, weight: .medium)
        restoreButton.addTarget(self, action: #selector(restoreTapped), for: .touchUpInside)

        let hint = UILabel()
        hint.text = String(localized: "about.restore_hint")
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
        label.text = String(localized: "about.copyright")
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
        showPlaceholder(title: String(localized: "about.privacy_policy"))
    }

    @objc private func termsTapped() {
        showPlaceholder(title: String(localized: "about.terms"))
    }

    @objc private func licensesTapped() {
        showPlaceholder(title: String(localized: "about.licenses"))
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
                showAlert(
                    title: String(localized: "about.restore_title"),
                    message: String(localized: "about.restore_success")
                )
            } catch {
                let format = String(localized: "about.restore_error_format")
                showAlert(
                    title: String(localized: "about.restore_title"),
                    message: String(format: format, error.localizedDescription)
                )
            }
        }
    }

    private func showPlaceholder(title: String) {
        showAlert(title: title, message: String(localized: "about.placeholder_message"))
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: String(localized: "common.ok"), style: .default))
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
