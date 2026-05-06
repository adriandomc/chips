import UIKit

/// Teclado de piano del mockup del synth — multi-octava, blancas y negras.
public final class ChipsPianoKeyboard: UIView {
    public var startingMidiNote: Int = 48 // C3
    public var numberOfWhiteKeys: Int = 14

    public var onNoteOn: ((Int) -> Void)?
    public var onNoteOff: ((Int) -> Void)?

    private var whiteRects: [(rect: CGRect, midi: Int)] = []
    private var blackRects: [(rect: CGRect, midi: Int)] = []
    private var pressedNotes: Set<Int> = []
    private var touchToNote: [ObjectIdentifier: Int] = [:]

    override public init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = ChipsTheme.contentBackground
        isMultipleTouchEnabled = true
    }

    @available(*, unavailable)
    public required init?(coder _: NSCoder) {
        fatalError("ChipsPianoKeyboard no soporta NSCoder")
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        rebuildKeyRects()
        setNeedsDisplay()
    }

    private func rebuildKeyRects() {
        whiteRects.removeAll()
        blackRects.removeAll()
        let whiteWidth = bounds.width / CGFloat(numberOfWhiteKeys)
        let whiteHeight = bounds.height
        let blackWidth = whiteWidth * 0.6
        let blackHeight = whiteHeight * 0.62

        var whiteIndex = 0
        var midi = startingMidiNote
        // Ajustar al primer C/blanca natural si toca una sostenida.
        while !isWhiteKey(midi: midi) { midi += 1 }

        while whiteIndex < numberOfWhiteKeys {
            let x = CGFloat(whiteIndex) * whiteWidth
            let rect = CGRect(x: x, y: 0, width: whiteWidth, height: whiteHeight)
            whiteRects.append((rect, midi))
            // Sostenida tras esta tecla, si existe.
            let nextMidi = midi + 1
            if !isWhiteKey(midi: nextMidi), whiteIndex < numberOfWhiteKeys - 1 {
                let bx = x + whiteWidth - blackWidth / 2
                let blackRect = CGRect(x: bx, y: 0, width: blackWidth, height: blackHeight)
                blackRects.append((blackRect, nextMidi))
            }
            // Avanzar a siguiente blanca.
            midi = nextMidi
            if !isWhiteKey(midi: midi) { midi += 1 }
            whiteIndex += 1
        }
    }

    private func isWhiteKey(midi: Int) -> Bool {
        switch midi % 12 {
        case 0, 2, 4, 5, 7, 9, 11: true
        default: false
        }
    }

    override public func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        // Blancas.
        for (r, midi) in whiteRects {
            let pressed = pressedNotes.contains(midi)
            ctx.setFillColor((pressed ? ChipsTheme.accentCyan.withAlphaComponent(0.4) : UIColor.white).cgColor)
            ctx.fill(r)
            ctx.setStrokeColor(UIColor.black.cgColor)
            ctx.setLineWidth(1)
            ctx.stroke(r)
        }
        // Negras encima.
        for (r, midi) in blackRects {
            let pressed = pressedNotes.contains(midi)
            ctx.setFillColor((pressed ? ChipsTheme.accentCyan : UIColor.black).cgColor)
            ctx.fill(r)
        }
    }

    override public func touchesBegan(_ touches: Set<UITouch>, with _: UIEvent?) {
        for touch in touches {
            if let midi = midiNoteAt(touch.location(in: self)) {
                touchToNote[ObjectIdentifier(touch)] = midi
                pressedNotes.insert(midi)
                onNoteOn?(midi)
            }
        }
        setNeedsDisplay()
    }

    override public func touchesEnded(_ touches: Set<UITouch>, with _: UIEvent?) {
        for touch in touches {
            if let midi = touchToNote.removeValue(forKey: ObjectIdentifier(touch)) {
                pressedNotes.remove(midi)
                onNoteOff?(midi)
            }
        }
        setNeedsDisplay()
    }

    override public func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }

    private func midiNoteAt(_ point: CGPoint) -> Int? {
        // Negras tienen prioridad porque están encima.
        for (r, midi) in blackRects where r.contains(point) {
            return midi
        }
        for (r, midi) in whiteRects where r.contains(point) {
            return midi
        }
        return nil
    }

    override public var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 140)
    }
}
