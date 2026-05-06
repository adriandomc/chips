import UIKit

/// Caja de texto blanca con borde fino — usada en el form de Settings.
public final class ChipsTextField: UIView {
    private let textField = UITextField()
    private let strokeLayer = CAShapeLayer()

    public var text: String? {
        get { textField.text }
        set { textField.text = newValue }
    }

    public var placeholder: String? {
        get { textField.placeholder }
        set { textField.placeholder = newValue }
    }

    public var alignment: NSTextAlignment {
        get { textField.textAlignment }
        set { textField.textAlignment = newValue }
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = ChipsTheme.displayBackground
        layer.addSublayer(strokeLayer)
        strokeLayer.fillColor = nil
        strokeLayer.strokeColor = ChipsTheme.buttonStroke.cgColor
        strokeLayer.lineWidth = 1

        textField.font = ChipsTheme.Font.body(size: 14)
        textField.textColor = ChipsTheme.textPrimary
        textField.borderStyle = .none
        textField.translatesAutoresizingMaskIntoConstraints = false
        addSubview(textField)
        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            textField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            textField.topAnchor.constraint(equalTo: topAnchor),
            textField.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    public required init?(coder _: NSCoder) {
        fatalError("ChipsTextField no soporta NSCoder")
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        strokeLayer.frame = bounds
        strokeLayer.path = UIBezierPath(rect: bounds.insetBy(dx: 0.5, dy: 0.5)).cgPath
    }

    override public var intrinsicContentSize: CGSize {
        CGSize(width: 200, height: 30)
    }
}
