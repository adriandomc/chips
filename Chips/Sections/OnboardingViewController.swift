import ChipsUIKit
import UIKit

/// Onboarding mínimo de 4 páginas que se muestra al primer launch. Diseño:
/// fondo `contentBackground`, ícono geométrico arriba, título mono grande,
/// body en sans, indicador de páginas y dos botones (Skip / Next / Get
/// Started). Sin animaciones complejas — cross-fade entre páginas.
@MainActor
final class OnboardingViewController: UIViewController {
    /// Llamado cuando el usuario completa o salta el flujo.
    var onComplete: (() -> Void)?

    private let pages = OnboardingPage.allCases
    private(set) var currentIndex: Int = 0

    private let pageContainer = UIView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let iconHost = UIView()
    private var iconView: OnboardingIconView?
    private let dotsStack = UIStackView()
    private let skipButton = ChipsButton()
    private let nextButton = ChipsButton()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ChipsTheme.contentBackground
        configureLabels()
        configureButtons()
        configureDots()
        layoutContent()
        showPage(at: 0, animated: false)
    }

    private func configureLabels() {
        titleLabel.font = ChipsTheme.Font.mono(size: 28, weight: .bold)
        titleLabel.textColor = ChipsTheme.textPrimary
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 2

        subtitleLabel.font = ChipsTheme.Font.body(size: 15)
        subtitleLabel.textColor = ChipsTheme.textSecondary
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
    }

    private func configureButtons() {
        skipButton.title = "SKIP"
        skipButton.titleFont = ChipsTheme.Font.mono(size: 11, weight: .semibold)
        skipButton.contentInsets = .init(top: 8, left: 14, bottom: 8, right: 14)
        skipButton.addTarget(self, action: #selector(skipTapped), for: .touchUpInside)

        nextButton.title = "NEXT"
        nextButton.titleFont = ChipsTheme.Font.mono(size: 13, weight: .semibold)
        nextButton.contentInsets = .init(top: 12, left: 24, bottom: 12, right: 24)
        nextButton.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)
    }

    private func configureDots() {
        dotsStack.axis = .horizontal
        dotsStack.spacing = 8
        dotsStack.alignment = .center
        dotsStack.distribution = .equalSpacing
        for _ in pages {
            let dot = UIView()
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.widthAnchor.constraint(equalToConstant: 8).isActive = true
            dot.heightAnchor.constraint(equalToConstant: 8).isActive = true
            dot.layer.cornerRadius = 4
            dot.backgroundColor = ChipsTheme.buttonGray
            dot.layer.borderColor = ChipsTheme.panelStroke.cgColor
            dot.layer.borderWidth = 1
            dotsStack.addArrangedSubview(dot)
        }
    }

    private func layoutContent() {
        skipButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(skipButton)

        iconHost.translatesAutoresizingMaskIntoConstraints = false
        iconHost.backgroundColor = .clear
        view.addSubview(iconHost)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(subtitleLabel)

        dotsStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(dotsStack)

        nextButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(nextButton)

        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            skipButton.topAnchor.constraint(equalTo: safe.topAnchor, constant: 16),
            skipButton.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -16),

            iconHost.topAnchor.constraint(equalTo: safe.topAnchor, constant: 64),
            iconHost.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 32),
            iconHost.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -32),
            iconHost.heightAnchor.constraint(equalTo: iconHost.widthAnchor, multiplier: 0.7),

            titleLabel.topAnchor.constraint(equalTo: iconHost.bottomAnchor, constant: 32),
            titleLabel.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -24),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            subtitleLabel.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 32),
            subtitleLabel.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -32),

            dotsStack.bottomAnchor.constraint(equalTo: nextButton.topAnchor, constant: -28),
            dotsStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            nextButton.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -24),
            nextButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }

    private func showPage(at index: Int, animated: Bool) {
        guard pages.indices.contains(index) else { return }
        currentIndex = index
        let page = pages[index]

        let newIcon = OnboardingIconView(page: page)
        newIcon.translatesAutoresizingMaskIntoConstraints = false
        iconHost.addSubview(newIcon)
        NSLayoutConstraint.activate([
            newIcon.topAnchor.constraint(equalTo: iconHost.topAnchor),
            newIcon.bottomAnchor.constraint(equalTo: iconHost.bottomAnchor),
            newIcon.leadingAnchor.constraint(equalTo: iconHost.leadingAnchor),
            newIcon.trailingAnchor.constraint(equalTo: iconHost.trailingAnchor),
        ])

        let oldIcon = iconView
        iconView = newIcon

        let updateLabels = {
            self.titleLabel.text = page.title
            self.subtitleLabel.text = page.subtitle
            self.nextButton.title = (index == self.pages.count - 1) ? "GET STARTED" : "NEXT"
        }
        updateDots()

        if animated {
            newIcon.alpha = 0
            UIView.animate(withDuration: 0.22, animations: {
                oldIcon?.alpha = 0
                newIcon.alpha = 1
                self.titleLabel.alpha = 0
                self.subtitleLabel.alpha = 0
            }, completion: { _ in
                oldIcon?.removeFromSuperview()
                updateLabels()
                UIView.animate(withDuration: 0.22) {
                    self.titleLabel.alpha = 1
                    self.subtitleLabel.alpha = 1
                }
            })
        } else {
            oldIcon?.removeFromSuperview()
            updateLabels()
        }
    }

    private func updateDots() {
        for (i, dot) in dotsStack.arrangedSubviews.enumerated() {
            dot.backgroundColor = (i == currentIndex) ? ChipsTheme.textPrimary : ChipsTheme.buttonGray
        }
    }

    @objc private func nextTapped() {
        if currentIndex == pages.count - 1 {
            complete()
        } else {
            showPage(at: currentIndex + 1, animated: true)
        }
    }

    @objc private func skipTapped() {
        complete()
    }

    private func complete() {
        OnboardingState.markCompleted()
        onComplete?()
    }
}
