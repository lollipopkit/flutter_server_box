//
//  DynamicIslandBrand.swift
//  Runner
//

import UIKit

/// Draws the app's name in the strip of screen the Dynamic Island covers.
///
/// The pill is composited by the system above every app window, so this is
/// invisible while the phone is in use. A screenshot captures the app's own
/// layers and not that overlay, so the name is what lands in the image — which
/// is how an app labels the screenshots its users share.
///
/// Portrait Dynamic Island devices only. In landscape the pill moves to the
/// long edge, and a notch is both narrower and a different shape, so on either
/// the label would sit in plain view instead of behind something.
final class DynamicIslandBrand {
    static let shared = DynamicIslandBrand()

    private enum DefaultsKey {
        static let background = "island_brand_bg"
        static let foreground = "island_brand_fg"
    }

    private var window: UIWindow?
    private weak var controller: BrandViewController?

    private init() {}

    /// Idempotent per scene. `UIApplicationSupportsMultipleScenes` is false so
    /// there is only ever one, but a scene can disconnect and reconnect, and
    /// the window has to belong to whichever one is live now.
    func install(in scene: UIWindowScene) {
        if let window, window.windowScene === scene { return }

        let controller = BrandViewController()
        let window = PassthroughWindow(windowScene: scene)
        // Above Flutter's window, below everything the system puts up: an alert
        // or a share sheet that dims the status bar area should dim this too.
        window.windowLevel = .normal + 1
        window.backgroundColor = .clear
        window.isUserInteractionEnabled = false
        window.rootViewController = controller
        // Deliberately not `makeKeyAndVisible`. iOS asks the *key* window's root
        // view controller for the status bar style and the supported
        // orientations, and neither answer should come from here.
        window.isHidden = false

        self.window = window
        self.controller = controller
        applyStoredColors()
        UserDefaults.standard.set("\(window.frame) lvl=\(window.windowLevel.rawValue) hidden=\(window.isHidden)", forKey: "dbg_install")
    }

    /// Take the app's current theme colors, as ARGB.
    ///
    /// Pushed from Dart on every theme change, and persisted, because a cold
    /// launch draws this before any Dart code has run.
    func setColors(background: Int, foreground: Int) {
        let defaults = UserDefaults.standard
        defaults.set(background, forKey: DefaultsKey.background)
        defaults.set(foreground, forKey: DefaultsKey.foreground)
        applyStoredColors()
    }

    private func applyStoredColors() {
        let defaults = UserDefaults.standard
        guard
            defaults.object(forKey: DefaultsKey.background) != nil,
            defaults.object(forKey: DefaultsKey.foreground) != nil
        else { return }  // Never pushed: the controller's own defaults stand.

        controller?.apply(
            background: UIColor(argb: defaults.integer(forKey: DefaultsKey.background)),
            foreground: UIColor(argb: defaults.integer(forKey: DefaultsKey.foreground))
        )
    }
}

/// Lets every touch through to the window below, including the ones landing on
/// the label itself.
private final class PassthroughWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? { nil }
}

private final class BrandViewController: UIViewController {
    /// Portrait geometry of the pill, in points. Apple publishes no API for it;
    /// these are community measurements, cross-checked against safe-area insets.
    private enum Island {
        /// Unchanged across every iPhone that has shipped one, 14 Pro onward.
        static let width: CGFloat = 126
        static let height: CGFloat = 37.33

        /// Gap between the bottom of the pill and the bottom of the top safe
        /// area inset. The pill's *top* offset is not a constant — 14 Pro
        /// through 16 put it at y≈11 under a 59pt inset, 16 Pro and 17 at y≈14
        /// under 62pt, iPhone Air lower still — but all of them leave this much
        /// below it. Anchoring to the bottom is what lets one number cover
        /// models that do not exist yet, where a hardcoded y or a table of
        /// device identifiers would be wrong on the next one.
        static let bottomMargin: CGFloat = 11.15

        /// Portrait `safeAreaInsets.top` is at least 59 on a Dynamic Island
        /// device and 47 or 48 on a notched one; landscape reports 0. One test
        /// excludes both — a notch is wider, shorter, and flush with the top
        /// edge, so the pill's geometry does not describe it.
        static let minSafeAreaTop: CGFloat = 55
    }

    /// The drawn badge sits well inside the island rather than filling it: a
    /// block the full size of the pill reads as a redaction bar in a
    /// screenshot, and the margin also absorbs the ~0.5pt the `bottomMargin`
    /// derivation is off by on known models.
    private enum Badge {
        static let height: CGFloat = 22
        static let textPadding: CGFloat = 9
        static let fontSize: CGFloat = 12
        /// Ceiling on the width, so a long app name cannot reach the edges of
        /// the island. 4pt clear on each side at the widest.
        static let maxWidth: CGFloat = Island.width - 8
    }

    private let badge = UIView()
    private let label = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false

        badge.layer.cornerRadius = Badge.height / 2
        badge.clipsToBounds = true
        view.addSubview(badge)

        label.text = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
        label.font = .systemFont(ofSize: Badge.fontSize, weight: .semibold)
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.7
        badge.addSubview(label)

        // Stands in until Dart pushes the theme, which it does at every launch.
        apply(background: .black, foreground: .white)
    }

    func apply(background: UIColor, foreground: UIColor) {
        badge.backgroundColor = background
        label.textColor = foreground
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()

        let safeTop = view.safeAreaInsets.top
        UserDefaults.standard.set("safeTop=\(safeTop) bounds=\(view.bounds)", forKey: "dbg_layout")
        let hasIsland = safeTop >= Island.minSafeAreaTop
        badge.isHidden = !hasIsland
        guard hasIsland else { return }

        let islandTop = safeTop - Island.bottomMargin - Island.height
        let text = (label.text ?? "") as NSString
        let textWidth = text.size(withAttributes: [.font: label.font as Any]).width
        let width = min(Badge.maxWidth, ceil(textWidth) + 2 * Badge.textPadding)

        badge.frame = CGRect(
            x: ((view.bounds.width - width) / 2).rounded(),
            y: (islandTop + (Island.height - Badge.height) / 2).rounded(),
            width: width,
            height: Badge.height
        )
        label.frame = badge.bounds.insetBy(dx: Badge.textPadding, dy: 0)
    }
}

private extension UIColor {
    /// Flutter hands colors over as ARGB, which is what `Color.toARGB32()`
    /// produces. Arrives as an `Int` because 0xFF000000 and up do not fit an
    /// Int32, so the codec widens it.
    convenience init(argb: Int) {
        let v = UInt32(truncatingIfNeeded: argb)
        self.init(
            red: CGFloat((v >> 16) & 0xFF) / 255,
            green: CGFloat((v >> 8) & 0xFF) / 255,
            blue: CGFloat(v & 0xFF) / 255,
            alpha: CGFloat((v >> 24) & 0xFF) / 255
        )
    }
}
