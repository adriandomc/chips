import UIKit

/// Fader vertical estilo mixer mockup. Track gris fino + handle ancho negro.
public final class ChipsFader: ChipsControl {
    public var minValue: Float = 0
    public var maxValue: Float = 1
    public var value: Float = 0.7 {
        didSet { setNeedsDisplay() }
    }

    public var trackColor: UIColor = ChipsTheme.panelStroke {
        didSet { setNeedsDisplay() }
    }

    public var handleColor: UIColor = ChipsTheme.textPrimary {
        didSet { setNeedsDisplay() }
    }

    override public func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        // Track central.
        let trackWidth: CGFloat = 4
        let trackRect = CGRect(
            x: rect.midX - trackWidth / 2,
            y: rect.minY + 8,
            width: trackWidth,
            height: rect.height - 16
        )
        ctx.setFillColor(trackColor.cgColor)
        ctx.fill(trackRect)

        // Handle.
        let normalized = max(0, min(1, (value - minValue) / max(0.0001, maxValue - minValue)))
        let handleHeight: CGFloat = 28
        let handleY = trackRect.maxY - handleHeight / 2 - CGFloat(normalized) * (trackRect.height - handleHeight)
        let handleRect = CGRect(
            x: rect.minX + 4,
            y: handleY - handleHeight / 2,
            width: rect.width - 8,
            height: handleHeight
        )
        ctx.setFillColor(handleColor.cgColor)
        ctx.fill(handleRect)
        // Línea blanca central del handle.
        ctx.setStrokeColor(UIColor.white.cgColor)
        ctx.setLineWidth(1)
        ctx.move(to: CGPoint(x: handleRect.minX + 2, y: handleRect.midY))
        ctx.addLine(to: CGPoint(x: handleRect.maxX - 2, y: handleRect.midY))
        ctx.strokePath()
    }

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
        let usableHeight = max(1, bounds.height - 32)
        value = max(minValue, min(maxValue, value + Float(deltaY) * range / Float(usableHeight)))
        sendActions(for: .valueChanged)
        return true
    }

    override public var intrinsicContentSize: CGSize {
        CGSize(width: 40, height: 200)
    }
}
