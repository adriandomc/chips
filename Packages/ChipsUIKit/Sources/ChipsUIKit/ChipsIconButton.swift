import UIKit

/// Botón cuadrado con un símbolo glyph (icono) — usado en la sidebar.
public final class ChipsIconButton: ChipsControl {
    private let iconView = UIImageView()

    public var systemImageName: String? {
        didSet { updateIcon() }
    }

    public var tintForeground: UIColor = ChipsTheme.textOnDark {
        didSet { iconView.tintColor = tintForeground }
    }

    public var iconSize: CGFloat = 22 {
        didSet { updateIcon() }
    }

    public var fillColor: UIColor = .clear {
        didSet { setNeedsDisplay() }
    }

    public var selectedFillColor: UIColor = UIColor.white.withAlphaComponent(0.18) {
        didSet { setNeedsDisplay() }
    }

    override public var isSelected: Bool {
        didSet { setNeedsDisplay() }
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)
        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = tintForeground
        iconView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconView)
        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        updateIcon()
    }

    private func updateIcon() {
        guard let name = systemImageName else {
            iconView.image = nil
            return
        }
        let config = UIImage.SymbolConfiguration(pointSize: iconSize, weight: .medium)
        iconView.image = UIImage(systemName: name, withConfiguration: config)
    }

    override public func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let color = isSelected || isHighlighted ? selectedFillColor : fillColor
        ctx.setFillColor(color.cgColor)
        ctx.fill(rect)
    }

    override public var intrinsicContentSize: CGSize {
        CGSize(width: 44, height: 44)
    }
}
