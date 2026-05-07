import UIKit

/// Botón rectangular con esquinas duras, fondo gris y borde fino, estilo del mockup
/// (NEW, SAVE, LOAD, TAP TEMPO, MASTER TRACK, STEMS).
public final class ChipsButton: ChipsControl {
    private let titleLabel = UILabel()
    private let strokeLayer = CAShapeLayer()

    public var title: String? {
        didSet {
            titleLabel.text = title?.uppercased()
            accessibilityLabel = title
        }
    }

    public var titleFont: UIFont = ChipsTheme.Font.mono(size: 13, weight: .semibold) {
        didSet { titleLabel.font = titleFont }
    }

    public var fillColor: UIColor = ChipsTheme.buttonGray {
        didSet { setNeedsDisplay() }
    }

    public var pressedFillColor: UIColor = ChipsTheme.buttonGrayPressed {
        didSet { setNeedsDisplay() }
    }

    public var strokeColor: UIColor = ChipsTheme.buttonStroke {
        didSet { strokeLayer.strokeColor = strokeColor.cgColor }
    }

    public var contentInsets = UIEdgeInsets(top: 6, left: 14, bottom: 6, right: 14) {
        didSet { invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)
        layer.addSublayer(strokeLayer)
        strokeLayer.fillColor = nil
        strokeLayer.strokeColor = strokeColor.cgColor
        strokeLayer.lineWidth = 1.0

        titleLabel.font = titleFont
        titleLabel.textColor = ChipsTheme.buttonText
        titleLabel.textAlignment = .center
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.7
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: contentInsets.left),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -contentInsets.right),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: contentInsets.top),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -contentInsets.bottom),
        ])
        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    override public func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let color = isHighlighted ? pressedFillColor : fillColor
        ctx.setFillColor(color.cgColor)
        ctx.fill(rect)
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        let inset: CGFloat = 0.5
        let path = UIBezierPath(rect: bounds.insetBy(dx: inset, dy: inset))
        strokeLayer.path = path.cgPath
        strokeLayer.frame = bounds
    }

    override public var isHighlighted: Bool {
        didSet { setNeedsDisplay() }
    }

    override public var intrinsicContentSize: CGSize {
        let textSize = titleLabel.intrinsicContentSize
        return CGSize(
            width: ceil(textSize.width + contentInsets.left + contentInsets.right),
            height: ceil(textSize.height + contentInsets.top + contentInsets.bottom)
        )
    }
}
