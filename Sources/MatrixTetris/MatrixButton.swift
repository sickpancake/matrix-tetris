import AppKit

final class MatrixButton: NSButton {
    override var title: String {
        didSet {
            applyTitleStyle()
        }
    }

    init(title: String = "", target: AnyObject?, action: Selector?) {
        super.init(frame: .zero)
        self.title = title
        self.target = target
        self.action = action
        configure()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var intrinsicContentSize: NSSize {
        let size = super.intrinsicContentSize
        return NSSize(width: max(72, size.width + 18), height: max(24, size.height + 7))
    }

    override var isHighlighted: Bool {
        didSet {
            refreshLayer()
        }
    }

    private func configure() {
        isBordered = false
        wantsLayer = true
        font = .monospacedSystemFont(ofSize: 11.5, weight: .medium)
        contentTintColor = NSColor(calibratedRed: 0.54, green: 1, blue: 0.66, alpha: 1)
        lineBreakMode = .byTruncatingTail
        setButtonType(.momentaryPushIn)
        applyTitleStyle()
        refreshLayer()
    }

    private func applyTitleStyle() {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 11.5, weight: .medium),
            .foregroundColor: NSColor(calibratedRed: 0.54, green: 1, blue: 0.66, alpha: 1)
        ]
        let alternateAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 11.5, weight: .semibold),
            .foregroundColor: NSColor(calibratedRed: 0.76, green: 1, blue: 0.82, alpha: 1)
        ]
        attributedTitle = NSAttributedString(string: title, attributes: attributes)
        attributedAlternateTitle = NSAttributedString(string: title, attributes: alternateAttributes)
    }

    private func refreshLayer() {
        layer?.cornerRadius = 4
        layer?.borderWidth = 1
        layer?.borderColor = NSColor(calibratedRed: 0.13, green: 1, blue: 0.36, alpha: isHighlighted ? 0.95 : 0.62).cgColor
        layer?.backgroundColor = NSColor(calibratedRed: 0, green: isHighlighted ? 0.12 : 0.055, blue: 0.026, alpha: 0.9).cgColor
        layer?.shadowColor = NSColor(calibratedRed: 0.12, green: 1, blue: 0.35, alpha: 0.55).cgColor
        layer?.shadowOpacity = isHighlighted ? 0.35 : 0.16
        layer?.shadowRadius = isHighlighted ? 5 : 3
        layer?.shadowOffset = .zero
    }
}
