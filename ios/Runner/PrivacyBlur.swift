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
/// Off by default; the app's settings page turns it on.
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

    /// Whether the content must stay covered even once the app is frontmost,
    /// because Dart has not yet decided whether a biometric lock is coming.
    ///
    /// Without this the blur would come off on `didActivate`, and the real UI
    /// would be on screen for the frames it takes Flutter to hear about the
    /// lifecycle change at all.
    ///
    /// It is released *before* the lock screen is pushed, not after it is
    /// dismissed. That screen is a Flutter route, drawn inside the window this
    /// view is layered on top of, so holding the cover through it would hide
    /// the very thing it was being held for.
    private(set) var isLocked = false

    private weak var blur: UIVisualEffectView?

    private init() {}

    func show(in scene: UIWindowScene) {
        guard isEnabled, blur == nil, let host = Self.hostWindow(in: scene) else { return }

        // `.regular` rather than one of the `.system*Material` styles: those
        // carry a tint that reads as a flat panel, and the point here is that
        // the app's own layout stays recognisable while its text does not.
        let view = UIVisualEffectView(effect: UIBlurEffect(style: .regular))
        view.frame = host.bounds
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        // On by default on this class, and it would eat every tap meant for the
        // UI underneath for as long as the cover is up.
        view.isUserInteractionEnabled = false
        host.addSubview(view)
        // Synchronous, and with no animation: iOS takes the switcher snapshot
        // as soon as this notification is done being delivered, and a fade
        // would be caught part way through.
        host.layoutIfNeeded()

        blur = view
    }

    /// Called when the app comes forward. Keeps the cover on if Dart has said
    /// the app is still locked; `setLocked(false)` is then what takes it off.
    func hideIfUnlocked() {
        guard !isLocked else { return }
        hide()
    }

    func setLocked(_ locked: Bool) {
        isLocked = locked
        // Only unlocking while frontmost may remove it — unlocking in the
        // background would strip the cover from the switcher card itself.
        if !locked, UIApplication.shared.applicationState == .active {
            hide()
        }
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
