//
//  PrivacyBlur.swift
//  Runner
//

import UIKit

/// Blurs the app while it is off screen, so the card iOS shows in the app
/// switcher does not leave server names, terminal output or file paths legible
/// to whoever is looking at the phone.
///
/// The blur goes into the Flutter window rather than a window of its own: a
/// `UIVisualEffectView` samples what is behind it, and behind it within the
/// same window is exactly the content that has to be hidden. That also leaves
/// `DynamicIslandBrand`'s overlay — a higher window level — untouched, which is
/// the point. The switcher card exposes the Dynamic Island strip the same way a
/// screenshot does, so the app name stays readable above the blur.
///
/// Off by default; the app's iOS settings page turns it on.
final class PrivacyBlur {
    static let shared = PrivacyBlur()

    private static let defaultsKey = "privacy_blur_on_background"

    /// Mirrored into `UserDefaults` because the first thing a user does after a
    /// cold launch may well be to switch away, and Dart has no way to have
    /// pushed anything by then. The setting store is still the source of truth
    /// and re-pushes on every launch.
    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Self.defaultsKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.defaultsKey) }
    }

    private weak var blur: UIVisualEffectView?

    private init() {}

    func show(in scene: UIWindowScene) {
        guard isEnabled, blur == nil, let host = Self.hostWindow(in: scene) else { return }

        let view = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
        view.frame = host.bounds
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        host.addSubview(view)
        // Synchronous, and with no animation: iOS takes the switcher snapshot
        // as soon as this notification is done being delivered, and a fade
        // would be caught part way through.
        host.layoutIfNeeded()

        blur = view
    }

    func hide() {
        blur?.removeFromSuperview()
        blur = nil
    }

    /// Flutter's window: the one at `.normal`, as opposed to the overlay
    /// `DynamicIslandBrand` installs above it.
    private static func hostWindow(in scene: UIWindowScene) -> UIWindow? {
        scene.windows.first { $0.windowLevel == .normal }
    }
}
