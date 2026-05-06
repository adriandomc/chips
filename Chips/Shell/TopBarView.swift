import ChipsUIKit
import UIKit

final class TopBarView: UIView {
    let timecode = ChipsTimecodeLabel()
    let playButton = ChipsTransportButton(kind: .play)
    let stopButton = ChipsTransportButton(kind: .stop)

    private let bottomStroke = CALayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = ChipsTheme.topBarBackground
        layer.addSublayer(bottomStroke)
        bottomStroke.backgroundColor = ChipsTheme.topBarStroke.cgColor

        timecode.text = "1.1.00"
        timecode.translatesAutoresizingMaskIntoConstraints = false
        addSubview(timecode)

        playButton.translatesAutoresizingMaskIntoConstraints = false
        stopButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(playButton)
        addSubview(stopButton)

        NSLayoutConstraint.activate([
            timecode.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            timecode.centerYAnchor.constraint(equalTo: centerYAnchor),
            timecode.widthAnchor.constraint(equalToConstant: 76),
            timecode.heightAnchor.constraint(equalToConstant: 28),

            playButton.leadingAnchor.constraint(equalTo: timecode.trailingAnchor, constant: 12),
            playButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            playButton.widthAnchor.constraint(equalToConstant: 32),
            playButton.heightAnchor.constraint(equalToConstant: 26),

            stopButton.leadingAnchor.constraint(equalTo: playButton.trailingAnchor, constant: 6),
            stopButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            stopButton.widthAnchor.constraint(equalToConstant: 32),
            stopButton.heightAnchor.constraint(equalToConstant: 26),
        ])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("TopBarView no soporta NSCoder")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        bottomStroke.frame = CGRect(x: 0, y: bounds.height - 1, width: bounds.width, height: 1)
    }
}
