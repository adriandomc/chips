import UIKit

/// Botones de Play/Stop estilo mockup: triángulo verde y cuadrado rojo
/// dibujados directamente.
public final class ChipsTransportButton: ChipsControl {
    public enum Kind {
        case play, stop
    }

    public let kind: Kind

    public init(kind: Kind) {
        self.kind = kind
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    override public init(frame _: CGRect) {
        fatalError("Use init(kind:)")
    }

    override public func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        switch kind {
        case .play:
            let fill = isHighlighted ? ChipsTheme.transportGreen.withAlphaComponent(0.7) : ChipsTheme.transportGreen
            let stroke = ChipsTheme.transportGreenStroke
            drawPlayTriangle(in: rect, ctx: ctx, fill: fill, stroke: stroke)
        case .stop:
            let fill = isHighlighted ? ChipsTheme.transportRed.withAlphaComponent(0.7) : ChipsTheme.transportRed
            let stroke = ChipsTheme.transportRedStroke
            drawStopSquare(in: rect, ctx: ctx, fill: fill, stroke: stroke)
        }
    }

    private func drawPlayTriangle(in rect: CGRect, ctx: CGContext, fill: UIColor, stroke: UIColor) {
        let inset: CGFloat = 4
        let r = rect.insetBy(dx: inset, dy: inset)
        let path = UIBezierPath()
        path.move(to: CGPoint(x: r.minX, y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX, y: r.midY))
        path.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        path.close()
        ctx.setFillColor(fill.cgColor)
        ctx.addPath(path.cgPath)
        ctx.fillPath()
        ctx.setStrokeColor(stroke.cgColor)
        ctx.setLineWidth(1.5)
        ctx.addPath(path.cgPath)
        ctx.strokePath()
    }

    private func drawStopSquare(in rect: CGRect, ctx: CGContext, fill: UIColor, stroke: UIColor) {
        let inset: CGFloat = 6
        let r = rect.insetBy(dx: inset, dy: inset)
        ctx.setFillColor(fill.cgColor)
        ctx.fill(r)
        ctx.setStrokeColor(stroke.cgColor)
        ctx.setLineWidth(1.5)
        ctx.stroke(r)
    }

    override public var isHighlighted: Bool {
        didSet { setNeedsDisplay() }
    }

    override public var intrinsicContentSize: CGSize {
        CGSize(width: 32, height: 26)
    }
}
