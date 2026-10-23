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
///
/// Beside them, what iPhone Duo's bars at the side leave a Flutter app to do
/// itself: where its own rail goes — see [verticalBar] — and how far its
/// content keeps from the screen's corners, with no status bar across the top.
final class WindowControls {
    static let shared = WindowControls()

    /// `[left, top, right, bottom]` per covered corner.
    private(set) var zones: [[Double]] = []

    /// `[x, top, x, bottom]`: the line the vertical bar is centred on, or nil.
    private(set) var bar: [Double]?

    /// `[left, top, right, bottom]`: the insets content keeps while the bars
    /// are at the side — the safe area's, adapted to the corners: across for
    /// the sides, down for the top and bottom. All 0 while they are not.
    private(set) var corners: [Double] = [0, 0, 0, 0]

    /// All three, as the channel sends them.
    var state: [String: Any] { ["zones": zones, "bar": bar as Any? ?? NSNull(), "corners": corners] }

    /// Called on the main thread whenever [state] changes.
    var onChange: (([String: Any]) -> Void)?

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

        let container = ProbeContainer { [weak self] zones, bar, corners in
            self?.update(zones, bar, corners)
        }
        view.addSubview(container)
        container.pin(to: view)
        probes = container
    }

    private func update(_ zones: [[Double]], _ bar: [Double]?, _ corners: [Double]) {
        guard zones != self.zones || bar != self.bar || corners != self.corners else { return }
        self.zones = zones
        self.bar = bar
        self.corners = corners
        onChange?(state)
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
    private let report: ([[Double]], [Double]?, [Double]) -> Void
    private let horizontal = Probe()
    private let vertical = Probe()

    init(report: @escaping ([[Double]], [Double]?, [Double]) -> Void) {
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
        let bar = verticalBar(in: view)
        var corners: [Double] = [0, 0, 0, 0]
        if bar != nil {
            let across = view.edgeInsets(for: .safeArea(cornerAdaptation: .horizontal))
            let down = view.edgeInsets(for: .safeArea(cornerAdaptation: .vertical))
            corners = [across.left, down.top, across.right, down.bottom].map { Double($0) }
        }
        report(windowControls(in: view), bar, corners)
    }

    private func windowControls(in view: UIView) -> [[Double]] {
        let safe = view.safeAreaInsets
        let wide = view.edgeInsets(for: .safeArea(cornerAdaptation: .horizontal))
        let tall = view.edgeInsets(for: .safeArea(cornerAdaptation: .vertical))
        let width = Double(view.bounds.width)
        let bottom = Double(max(tall.top, safe.top))

        var zones: [[Double]] = []
        // A window as large as the screen still rounds its corners, and the
        // horizontal region steps around that too — but within the status
        // bar, which the content is already below.
        guard bottom > Double(safe.top) else { return zones }
        if wide.left > safe.left {
            zones.append([0, 0, Double(wide.left), bottom])
        }
        if wide.right > safe.right {
            zones.append([width - Double(wide.right), 0, width, bottom])
        }
        return zones
    }

    /// The line iPhone Duo centres its vertical bar on, from below the status
    /// bar and camera to the bottom inset: `[x, top, x, bottom]`, or nil
    /// wherever the system lays its bars across the top and bottom.
    ///
    /// Asked of the system as a bar of no width on the bar's edge, rather than
    /// worked out from the side inset: the bar and the status bar above it
    /// stand off the middle of that inset, and a rail centred on the inset
    /// stood beside them.
    ///
    /// Through the runtime: `verticalBarEdge` and bar layout regions are iOS
    /// 27.1 SDK API, and a build against an older SDK has to compile.
    private func verticalBar(in view: UIView) -> [Double]? {
        let traits = view.traitCollection
        guard traits.responds(to: NSSelectorFromString("verticalBarEdge")),
              let edge = (traits.value(forKey: "verticalBarEdge") as? NSNumber)?.intValue,
              edge != 0,
              let insets = barInsets(in: view, leading: edge == 1)
        else { return nil }
        // A bar of no width: what is left of it is where it stands.
        let x = Double(insets.left)
        let top = Double(insets.top)
        let bottom = Double(view.bounds.height - insets.bottom)
        guard bottom > top else { return nil }
        return [x, top, x, bottom]
    }

    /// `edgeInsetsForLayoutRegion:` of a bar of no width on the leading or
    /// trailing edge.
    private func barInsets(in view: UIView, leading: Bool) -> UIEdgeInsets? {
        let make = NSSelectorFromString("layoutRegionForBarOnDirectionalEdge:extent:")
        let measure = NSSelectorFromString("edgeInsetsForLayoutRegion:")
        guard let regions = NSClassFromString("UIViewLayoutRegion") as AnyObject?,
              regions.responds(to: make),
              view.responds(to: measure)
        else { return nil }
        typealias Make = @convention(c) (AnyObject, Selector, UInt, CGFloat) -> Unmanaged<AnyObject>
        typealias Measure = @convention(c) (AnyObject, Selector, AnyObject) -> UIEdgeInsets
        let edge: NSDirectionalRectEdge = leading ? .leading : .trailing
        let region = unsafeBitCast(regions.method(for: make), to: Make.self)(regions, make, edge.rawValue, 0)
            .takeUnretainedValue()
        return unsafeBitCast(view.method(for: measure), to: Measure.self)(view, measure, region)
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
