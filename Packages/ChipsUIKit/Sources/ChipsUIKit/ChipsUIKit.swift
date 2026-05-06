import UIKit

public enum ChipsUIKit {
    public static let version = "0.0.1-m0"
}

/// Clase base de todos los componentes custom de Chips. Las subclases concretas
/// (knob, slider, button, meter, etc.) llegan en M3 una vez existan los diseños.
open class ChipsControl: UIControl {
    override public init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isMultipleTouchEnabled = false
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("ChipsControl no soporta NSCoder")
    }
}
