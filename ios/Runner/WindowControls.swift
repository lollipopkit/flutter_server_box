//
//  WindowControls.swift
//  Runner
//

import Flutter
import UIKit

/// Reports to Dart where the system's window controls cover the app.
///
/// A windowed scene on iPadOS 26 draws its close, minimise and tile buttons
/// over the top corner of the app's own content. UIKit's bars step around
/// them through the corner-adapted layout regions; `safeAreaInsets`, the one
/// number the Flutter engine hands on as `MediaQuery.padding`, leaves them
/// out, so a Flutter app bar put its back button under them.
///
/// The covered area is the corner where an inset adapted on one axis grows
/// past the plain safe area: the horizontal adaptation gives its width, the
/// vertical one its height. Sent as a list of rects in the Flutter view's
/// coordinates, which are its points — empty when nothing is covered, as on
/// every iPhone and on a full-screen iPad scene.
final class WindowControls {
    static let shared = WindowControls()

    /// `[left, top, right, bottom]` per covered corner.
    private(set) var zones: [[Double]] = []

    /// Called on the main thread whenever [zones] changes.
    var onChange: (([[Double]]) -> Void)?

    /// `UIView` and not the probe type, which a stored property of a class
    /// that is not itself iOS 26-only cannot name.
    private weak var probes: UIView?

    private init() {}

    /// Idempotent per view: a scene reconnecting gets a new Flutter view, and
    /// the probes have to be measured against whichever one is live.
    func install(in scene: UIWindowScene) {
        guard #available(iOS 26.0, *) else { return }
        guard let view = scene.windows
            .lazy
            .compactMap({ $0.rootViewController as? FlutterViewController })
            .first?.view
        else { return }
        if let probes, probes.superview === view { return }
        probes?.removeFromSuperview()

        let container = ProbeContainer { [weak self] zones in
            self?.update(zones)
        }
        view.addSubview(container)
        container.pin(to: view)
        probes = container
    }

    private func update(_ zones: [[Double]]) {
        guard zones != self.zones else { return }
        self.zones = zones
        onChange?(zones)
    }
}

/// Invisible views pinned to the corner-adapted safe areas.
///
/// Measuring from layout instead of asking once: the controls come and go as
/// the scene moves between full screen and a window, and the regions follow
/// them. A probe pinned to a region is resized whenever the region changes,
/// and a resize is a `layoutSubviews` — the one notification UIKit gives.
@available(iOS 26.0, *)
private final class ProbeContainer: UIView {
    private let report: ([[Double]]) -> Void
    private let horizontal = Probe()
    private let vertical = Probe()

    init(report: @escaping ([[Double]]) -> Void) {
        self.report = report
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        isHidden = true
        translatesAutoresizingMaskIntoConstraints = false
        for probe in [horizontal, vertical] {
            probe.onLayout = { [weak self] in self?.measure() }
            probe.translatesAutoresizingMaskIntoConstraints = false
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    /// Spans the whole view; the probes inside follow its regions.
    func pin(to view: UIView) {
        NSLayoutConstraint.activate([
            leadingAnchor.constraint(equalTo: view.leadingAnchor),
            trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topAnchor.constraint(equalTo: view.topAnchor),
            bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        for (probe, axis) in [
            (horizontal, UIView.LayoutRegion.AdaptivityAxis.horizontal),
            (vertical, .vertical),
        ] {
            view.addSubview(probe)
            let guide = view.layoutGuide(for: .safeArea(cornerAdaptation: axis))
            NSLayoutConstraint.activate([
                probe.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
                probe.trailingAnchor.constraint(equalTo: guide.trailingAnchor),
                probe.topAnchor.constraint(equalTo: guide.topAnchor),
                probe.bottomAnchor.constraint(equalTo: guide.bottomAnchor),
            ])
        }
    }

    override func removeFromSuperview() {
        horizontal.removeFromSuperview()
        vertical.removeFromSuperview()
        super.removeFromSuperview()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        measure()
    }

    private func measure() {
        guard let view = superview else { return }
        let safe = view.safeAreaInsets
        let wide = view.edgeInsets(for: .safeArea(cornerAdaptation: .horizontal))
        let tall = view.edgeInsets(for: .safeArea(cornerAdaptation: .vertical))
        let width = Double(view.bounds.width)
        let bottom = Double(max(tall.top, safe.top))

        var zones: [[Double]] = []
        // A window as large as the screen still rounds its corners, and the
        // horizontal region steps around that too — but within the status
        // bar, which the content is already below.
        guard bottom > Double(safe.top) else {
            report(zones)
            return
        }
        if wide.left > safe.left {
            zones.append([0, 0, Double(wide.left), bottom])
        }
        if wide.right > safe.right {
            zones.append([width - Double(wide.right), 0, width, bottom])
        }
        report(zones)
    }
}

@available(iOS 26.0, *)
private final class Probe: UIView {
    var onLayout: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isHidden = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        onLayout?()
    }
}
