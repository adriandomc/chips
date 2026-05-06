import UIKit

public enum ChipsUIKit {
    public static let version = "0.3.0-m3"
}

/// Clase base de cualquier control custom de Chips. Sin background, sin
/// gestos por defecto. Las subclases dibujan vía `draw(_:)` o capas custom.
open class ChipsControl: UIControl {
    override public init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        contentMode = .redraw
        isMultipleTouchEnabled = false
    }

    @available(*, unavailable)
    public required init?(coder _: NSCoder) {
        fatalError("ChipsControl no soporta NSCoder")
    }
}
