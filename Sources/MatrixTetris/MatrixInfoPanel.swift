import AppKit

final class MatrixInfoPanel: NSView {
    private var callbacks: [Int: () -> Void] = [:]

    override var isFlipped: Bool { true }

    init(
        title: String,
        lines: [String],
        buttons: [(String, () -> Void)] = [],
        width: CGFloat = 188
    ) {
        let height = max(150, CGFloat(48 + lines.count * 44 + buttons.count * 34))
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: height))
        buildInterface(title: title, lines: lines, buttons: buttons, width: width)
    }

    required init?(coder: NSCoder) {
        nil
    }

    private func buildInterface(
        title: String,
        lines: [String],
        buttons: [(String, () -> Void)],
        width: CGFloat
    ) {
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.backgroundColor = NSColor(calibratedRed: 0, green: 0.04, blue: 0.018, alpha: 0.86).cgColor
        layer?.borderWidth = 1
        layer?.borderColor = NSColor(calibratedRed: 0.12, green: 0.9, blue: 0.32, alpha: 0.65).cgColor

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 7
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -10)
        ])

        stack.addArrangedSubview(label(title, size: 13, weight: .bold, alpha: 1, width: width - 20))

        for line in lines {
            stack.addArrangedSubview(label(line, size: 10.5, weight: .regular, alpha: 0.92, width: width - 20))
        }

        for (index, buttonSpec) in buttons.enumerated() {
            let button = MatrixButton(title: buttonSpec.0, target: self, action: #selector(buttonPressed(_:)))
            button.tag = index
            button.widthAnchor.constraint(equalToConstant: width - 20).isActive = true
            callbacks[index] = buttonSpec.1
            stack.addArrangedSubview(button)
        }
    }

    private func label(
        _ text: String,
        size: CGFloat,
        weight: NSFont.Weight,
        alpha: CGFloat,
        width: CGFloat
    ) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = .monospacedSystemFont(ofSize: size, weight: weight)
        field.textColor = NSColor(calibratedRed: 0.42, green: 1, blue: 0.56, alpha: alpha)
        field.maximumNumberOfLines = 0
        field.lineBreakMode = .byWordWrapping
        field.widthAnchor.constraint(equalToConstant: width).isActive = true
        return field
    }

    @objc private func buttonPressed(_ sender: NSButton) {
        callbacks[sender.tag]?()
    }
}
