import UIKit

/// Display tipo "1.1.00" — caja blanca con borde fino y fuente monospace.
public final class ChipsTimecodeLabel: UIView {
    private let label = UILabel()
    private let strokeLayer = CAShapeLayer()

    public var text: String? {
        didSet { label.text = text }
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = ChipsTheme.displayBackground
        layer.addSublayer(strokeLayer)
        strokeLayer.fillColor = nil
        strokeLayer.strokeColor = ChipsTheme.buttonStroke.cgColor
        strokeLayer.lineWidth = 1

        label.font = ChipsTheme.Font.display(size: 14)
        label.textColor = ChipsTheme.textPrimary
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            label.topAnchor.constraint(equalTo: topAnchor),
            label.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    public required init?(coder _: NSCoder) {
        fatalError("ChipsTimecodeLabel no soporta NSCoder")
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        strokeLayer.frame = bounds
        strokeLayer.path = UIBezierPath(rect: bounds.insetBy(dx: 0.5, dy: 0.5)).cgPath
    }

    override public var intrinsicContentSize: CGSize {
        CGSize(width: 72, height: 26)
    }
}
