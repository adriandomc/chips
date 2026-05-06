import ChipsUIKit
import UIKit

final class GridSectionViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ChipsTheme.contentBackground
        let label = UILabel()
        label.text = "Step grid — pendiente de M5"
        label.font = ChipsTheme.Font.body(size: 14)
        label.textColor = ChipsTheme.textSecondary
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }
}
