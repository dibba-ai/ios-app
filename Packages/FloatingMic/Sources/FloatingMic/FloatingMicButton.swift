import SwiftUI
import UIKit

/// Floating microphone button for embedding outside the tab bar (the tab-bar mic
/// is provided natively by `UISearchTab` on iOS 26).
///
/// Tap triggers `controller.tap()`.
///
/// Visual:
/// - iOS 26+: `UIGlassEffect(style: .regular)` — Liquid Glass material.
/// - iOS 25 and earlier: `UIBlurEffect(style: .systemMaterial)` capsule fallback.
public final class FloatingMicButton: UIControl {
    public let controller: FloatingMicController

    private let backgroundView: UIVisualEffectView
    private let iconView: UIImageView

    public init(controller: FloatingMicController = FloatingMicController()) {
        self.controller = controller

        let effect: UIVisualEffect
        if #available(iOS 26.0, *) {
            let glass = UIGlassEffect(style: .regular)
            glass.isInteractive = true
            effect = glass
        } else {
            effect = UIBlurEffect(style: .systemMaterial)
        }
        self.backgroundView = UIVisualEffectView(effect: effect)

        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)
        self.iconView = UIImageView(image: UIImage(systemName: "mic.fill", withConfiguration: symbolConfig))
        self.iconView.tintColor = .label
        self.iconView.contentMode = .center

        super.init(frame: .zero)
        setup()
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        let radius = min(bounds.width, bounds.height) / 2
        backgroundView.layer.cornerRadius = radius
        backgroundView.layer.cornerCurve = .continuous
    }

    private func setup() {
        backgroundView.isUserInteractionEnabled = false
        backgroundView.clipsToBounds = true
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(backgroundView)

        iconView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.contentView.addSubview(iconView)

        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),
            iconView.centerXAnchor.constraint(equalTo: backgroundView.contentView.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: backgroundView.contentView.centerYAnchor),
        ])

        addTarget(self, action: #selector(handleTap), for: .touchUpInside)

        accessibilityLabel = "Microphone"
        accessibilityTraits = .button
        isAccessibilityElement = true
    }

    @objc private func handleTap() {
        animatePress(true)
        controller.tap()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            self?.animatePress(false)
        }
    }

    private func animatePress(_ pressed: Bool) {
        UIView.animate(
            withDuration: 0.18,
            delay: 0,
            usingSpringWithDamping: 0.7,
            initialSpringVelocity: 0,
            options: [.allowUserInteraction, .beginFromCurrentState]
        ) {
            self.transform = pressed ? CGAffineTransform(scaleX: 0.92, y: 0.92) : .identity
        }
    }
}

// MARK: - SwiftUI Bridge

/// SwiftUI wrapper around `FloatingMicButton` for use inside SwiftUI hierarchies.
public struct FloatingMicButtonView: UIViewRepresentable {
    public init() {}

    public func makeUIView(context: Context) -> FloatingMicButton {
        FloatingMicButton()
    }

    public func updateUIView(_ uiView: FloatingMicButton, context: Context) {}
}
