import UIKit

/// Knob circular con cap interno oscuro y indicador de valor. Los knobs del mockup
/// del synth tienen acento cyan en el dial principal.
public final class ChipsKnob: ChipsControl {
    public var minValue: Float = 0
    public var maxValue: Float = 1
    public var value: Float = 0 {
        didSet { setNeedsDisplay() }
    }

    public var capColor: UIColor = ChipsTheme.panelGray {
        didSet { setNeedsDisplay() }
    }

    public var ringColor: UIColor = ChipsTheme.accentCyan {
        didSet { setNeedsDisplay() }
    }

    public var indicatorColor: UIColor = ChipsTheme.textPrimary {
        didSet { setNeedsDisplay() }
    }

    public var label: String? {
        didSet { labelView.text = label?.uppercased() }
    }

    private let labelView = UILabel()

    override public init(frame: CGRect) {
        super.init(frame: frame)
        labelView.font = ChipsTheme.Font.label(size: 10)
        labelView.textColor = ChipsTheme.textOnDark
        labelView.textAlignment = .center
        labelView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(labelView)
        NSLayoutConstraint.activate([
            labelView.leadingAnchor.constraint(equalTo: leadingAnchor),
            labelView.trailingAnchor.constraint(equalTo: trailingAnchor),
            labelView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    override public func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let labelHeight: CGFloat = label == nil ? 0 : 14
        let knobRect = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height - labelHeight)
        let inset: CGFloat = 6
        let circle = knobRect.insetBy(dx: inset, dy: inset)
        let radius = min(circle.width, circle.height) / 2
        let center = CGPoint(x: circle.midX, y: circle.midY)

        // Anillo exterior cyan (track del knob).
        ctx.setStrokeColor(ringColor.withAlphaComponent(0.4).cgColor)
        ctx.setLineWidth(3)
        ctx.addArc(
            center: center,
            radius: radius - 1.5,
            startAngle: degToRad(135),
            endAngle: degToRad(45),
            clockwise: false
        )
        ctx.strokePath()

        // Arco activo según valor.
        let normalized = max(0, min(1, (value - minValue) / max(0.0001, maxValue - minValue)))
        let endAngle = degToRad(135 + 270 * CGFloat(normalized))
        ctx.setStrokeColor(ringColor.cgColor)
        ctx.setLineWidth(3)
        ctx.addArc(
            center: center,
            radius: radius - 1.5,
            startAngle: degToRad(135),
            endAngle: endAngle,
            clockwise: false
        )
        ctx.strokePath()

        // Cap interno.
        let capRadius = radius - 6
        ctx.setFillColor(capColor.cgColor)
        ctx.addArc(center: center, radius: capRadius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
        ctx.fillPath()
        ctx.setStrokeColor(ChipsTheme.panelStroke.cgColor)
        ctx.setLineWidth(1)
        ctx.addArc(center: center, radius: capRadius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
        ctx.strokePath()

        // Indicador (línea desde el centro hasta el borde del cap).
        ctx.setStrokeColor(indicatorColor.cgColor)
        ctx.setLineWidth(2)
        ctx.move(to: center)
        let tipX = center.x + cos(endAngle) * (capRadius - 2)
        let tipY = center.y + sin(endAngle) * (capRadius - 2)
        ctx.addLine(to: CGPoint(x: tipX, y: tipY))
        ctx.strokePath()
    }

    private func degToRad(_ deg: CGFloat) -> CGFloat {
        deg * .pi / 180
    }

    /// Touch tracking: drag vertical para cambiar valor.
    private var lastTouchY: CGFloat = 0

    override public func beginTracking(_ touch: UITouch, with _: UIEvent?) -> Bool {
        lastTouchY = touch.location(in: self).y
        return true
    }

    override public func continueTracking(_ touch: UITouch, with _: UIEvent?) -> Bool {
        let location = touch.location(in: self)
        let deltaY = lastTouchY - location.y
        lastTouchY = location.y
        let range = maxValue - minValue
        value = max(minValue, min(maxValue, value + Float(deltaY) * range / 200))
        sendActions(for: .valueChanged)
        return true
    }

    override public var intrinsicContentSize: CGSize {
        CGSize(width: 56, height: 70)
    }
}
