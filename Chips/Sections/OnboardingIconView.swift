import ChipsUIKit
import UIKit

/// Vista que dibuja un glifo geométrico simple para cada página del
/// onboarding. Mantiene el estilo pixel-friendly del app: rectángulos con
/// stroke duro, paleta cálida acento. Cero dependencias en SF Symbols ni
/// emojis — todo lo que ves es CGContext.
final class OnboardingIconView: UIView {
    private let page: OnboardingPage

    init(page: OnboardingPage) {
        self.page = page
        super.init(frame: .zero)
        backgroundColor = .clear
        isOpaque = false
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("OnboardingIconView no soporta NSCoder")
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.setShouldAntialias(true)
        let inset: CGFloat = 24
        let frame = rect.insetBy(dx: inset, dy: inset)
        switch page {
        case .welcome: drawWelcome(in: ctx, frame: frame)
        case .sequencer: drawSequencer(in: ctx, frame: frame)
        case .soundDesign: drawSoundDesign(in: ctx, frame: frame)
        case .export: drawExport(in: ctx, frame: frame)
        }
    }

    // MARK: Page glyphs

    private func drawWelcome(in ctx: CGContext, frame: CGRect) {
        // Cuatro tiles de la paleta de tracks superpuestos en cuadrícula 2×2
        // — comunica "modular, muchas piezas".
        let tile = min(frame.width, frame.height) / 2.4
        let center = CGPoint(x: frame.midX, y: frame.midY)
        let offsets: [(dx: CGFloat, dy: CGFloat, color: UIColor)] = [
            (-tile / 1.6, -tile / 1.6, ChipsTheme.trackColor(at: 0)),
            (tile / 1.6, -tile / 1.6, ChipsTheme.trackColor(at: 3)),
            (-tile / 1.6, tile / 1.6, ChipsTheme.trackColor(at: 4)),
            (tile / 1.6, tile / 1.6, ChipsTheme.trackColor(at: 6)),
        ]
        for offset in offsets {
            let tileFrame = CGRect(
                x: center.x + offset.dx - tile / 2,
                y: center.y + offset.dy - tile / 2,
                width: tile,
                height: tile
            )
            offset.color.setFill()
            ctx.fill(tileFrame)
            ChipsTheme.panelStroke.setStroke()
            ctx.setLineWidth(2)
            ctx.stroke(tileFrame)
        }
    }

    private func drawSequencer(in ctx: CGContext, frame: CGRect) {
        // Grid 8×4 con algunas celdas activas (patrón musical reconocible).
        let cols = 8
        let rows = 4
        let cellW = frame.width / CGFloat(cols)
        let cellH = frame.height / CGFloat(rows)
        let active: Set<Int> = [0, 4, 9, 13, 18, 22, 25, 28] // 8 notas dispersas
        for row in 0 ..< rows {
            for col in 0 ..< cols {
                let cellFrame = CGRect(
                    x: frame.minX + CGFloat(col) * cellW,
                    y: frame.minY + CGFloat(row) * cellH,
                    width: cellW,
                    height: cellH
                ).insetBy(dx: 3, dy: 3)
                let index = row * cols + col
                if active.contains(index) {
                    ChipsTheme.trackColor(at: row).setFill()
                    ctx.fill(cellFrame)
                } else {
                    ChipsTheme.buttonGray.setFill()
                    ctx.fill(cellFrame)
                }
                ChipsTheme.panelStroke.setStroke()
                ctx.setLineWidth(1)
                ctx.stroke(cellFrame)
            }
        }
    }

    private func drawSoundDesign(in ctx: CGContext, frame: CGRect) {
        // Knob grande centrado: círculo con tick mark a las 2 en punto.
        let size = min(frame.width, frame.height) * 0.7
        let knobRect = CGRect(
            x: frame.midX - size / 2,
            y: frame.midY - size / 2,
            width: size,
            height: size
        )
        // Cuerpo
        ChipsTheme.buttonGray.setFill()
        ctx.fillEllipse(in: knobRect)
        ChipsTheme.panelStroke.setStroke()
        ctx.setLineWidth(3)
        ctx.strokeEllipse(in: knobRect)
        // Ring exterior con marcas
        let center = CGPoint(x: frame.midX, y: frame.midY)
        let outerR = size / 2 + 12
        let totalTicks = 11
        let startAngle = CGFloat.pi * 0.75
        let endAngle = CGFloat.pi * 2.25
        for i in 0 ..< totalTicks {
            let t = CGFloat(i) / CGFloat(totalTicks - 1)
            let angle = startAngle + (endAngle - startAngle) * t
            let inner = CGPoint(
                x: center.x + cos(angle) * (outerR - 6),
                y: center.y + sin(angle) * (outerR - 6)
            )
            let outer = CGPoint(
                x: center.x + cos(angle) * outerR,
                y: center.y + sin(angle) * outerR
            )
            ChipsTheme.panelStroke.setStroke()
            ctx.setLineWidth(2)
            ctx.move(to: inner)
            ctx.addLine(to: outer)
            ctx.strokePath()
        }
        // Indicador (apunta ~70% del rango)
        let indicatorAngle = startAngle + (endAngle - startAngle) * 0.7
        let indicatorEnd = CGPoint(
            x: center.x + cos(indicatorAngle) * (size / 2 - 8),
            y: center.y + sin(indicatorAngle) * (size / 2 - 8)
        )
        ChipsTheme.accentCyan.setStroke()
        ctx.setLineWidth(4)
        ctx.move(to: center)
        ctx.addLine(to: indicatorEnd)
        ctx.strokePath()
        // Punto central
        ChipsTheme.panelStroke.setFill()
        let dot = CGRect(x: center.x - 4, y: center.y - 4, width: 8, height: 8)
        ctx.fillEllipse(in: dot)
    }

    private func drawExport(in ctx: CGContext, frame: CGRect) {
        // Onda (3 picos) + flecha hacia arriba — "exportar lo que sonó".
        let waveHeight = frame.height * 0.4
        let waveBaseline = frame.midY + frame.height * 0.18
        ChipsTheme.accentCyan.setStroke()
        ctx.setLineWidth(4)
        ctx.setLineCap(.round)
        let segments = 6
        let stepX = frame.width / CGFloat(segments)
        ctx.move(to: CGPoint(x: frame.minX, y: waveBaseline))
        for i in 1 ... segments {
            let x = frame.minX + CGFloat(i) * stepX
            let amp = waveHeight * (i.isMultiple(of: 2) ? 1.0 : -1.0) * (1.0 - CGFloat(i) * 0.05)
            ctx.addLine(to: CGPoint(x: x, y: waveBaseline + amp))
        }
        ctx.strokePath()
        // Flecha hacia arriba
        let arrowSize: CGFloat = min(frame.width, frame.height) * 0.32
        let arrowCenterX = frame.midX
        let arrowTopY = frame.minY + frame.height * 0.05
        let arrowBottomY = arrowTopY + arrowSize
        ChipsTheme.transportGreen.setStroke()
        ctx.setLineWidth(5)
        ctx.move(to: CGPoint(x: arrowCenterX, y: arrowBottomY))
        ctx.addLine(to: CGPoint(x: arrowCenterX, y: arrowTopY))
        ctx.move(to: CGPoint(x: arrowCenterX - arrowSize / 3, y: arrowTopY + arrowSize / 4))
        ctx.addLine(to: CGPoint(x: arrowCenterX, y: arrowTopY))
        ctx.addLine(to: CGPoint(x: arrowCenterX + arrowSize / 3, y: arrowTopY + arrowSize / 4))
        ctx.strokePath()
    }
}
