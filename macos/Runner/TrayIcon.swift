//
//  TrayIcon.swift
//  Runner
//
//  The menu bar item, and the rows in its menu.
//

import Cocoa
import FlutterMacOS

/// The status item and the menu behind it.
///
/// Hand-written rather than a plugin because of what the rows are. The plugin
/// on pub sets an `NSMenuItem`'s `title` and nothing else — no image, no
/// attributed title, no view — and a row here is a name, a sparkline and a
/// line of readings. `NSMenuItem.view` takes any view, so on this platform the
/// layout costs a `draw(_:)` and nothing more.
///
/// Everything drawn is decided in Dart and arrives formatted: see `TrayModel`.
/// Nothing here knows what a percentage is, which server is which, or what any
/// of it means — it lays out strings and plots a series already scaled to 0…1.
@available(macOS 10.15, *)
final class TrayIcon: NSObject, NSMenuDelegate {
    static let shared = TrayIcon()

    private var statusItem: NSStatusItem?
    private var channel: FlutterMethodChannel?

    /// Rebuilt whole on every update, because that is what a menu is: there is
    /// no API for editing one item, and the Dart side already withholds a push
    /// that would change nothing.
    private let menu = NSMenu()

    func attach(_ channel: FlutterMethodChannel) {
        self.channel = channel
        channel.setMethodCallHandler { [weak self] call, result in
            guard let self else {
                result(nil)
                return
            }
            switch call.method {
            case "update":
                if let payload = call.arguments as? [String: Any] {
                    self.update(payload)
                }
                result(nil)
            case "destroy":
                self.destroy()
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    private func ensureItem() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        // A template image, so the system inverts it along with the menu bar
        // and it stays legible in both appearances.
        if let image = NSImage(named: "TrayIcon") {
            image.isTemplate = true
            item.button?.image = image
        } else {
            item.button?.title = "SB"
        }
        item.menu = menu
        menu.delegate = self
        statusItem = item
    }

    private func destroy() {
        guard let item = statusItem else { return }
        NSStatusBar.system.removeStatusItem(item)
        statusItem = nil
    }

    // MARK: - Building

    private func update(_ root: [String: Any]) {
        ensureItem()

        let config = root["config"] as? [String: Any] ?? [:]
        let compact = config["compact"] as? Bool ?? false
        let lines = root["lines"] as? [[String: Any]] ?? []

        menu.removeAllItems()

        menu.addItem(command(NSLocalizedString("Open ServerBox", comment: "Tray: bring the app forward"), "open"))
        menu.addItem(.separator())

        let header = NSMenuItem(title: NSLocalizedString("Servers", comment: "Tray: section heading"), action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        if lines.isEmpty {
            let empty = NSMenuItem(title: NSLocalizedString("Empty", comment: "Tray: no servers configured"), action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            for line in lines {
                menu.addItem(row(line, compact: compact))
            }
        }

        menu.addItem(.separator())
        menu.addItem(command(NSLocalizedString("Settings", comment: "Tray: open the settings page"), "settings"))
        menu.addItem(command(NSLocalizedString("Quit", comment: "Tray: leave the app"), "quit"))
    }

    private func command(_ title: String, _ method: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(onCommand(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = method
        return item
    }

    private func row(_ line: [String: Any], compact: Bool) -> NSMenuItem {
        let item = NSMenuItem(title: line["label"] as? String ?? "", action: #selector(onServer(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = line["id"] as? String
        // Compact stays a plain item: it is the one line a title already draws,
        // and a view would only reimplement the system's own text layout —
        // badly, since a menu item's font and insets are not public.
        if !compact {
            item.view = TrayRowView(line: line, item: item)
        }
        return item
    }

    // MARK: - Events

    @objc private func onCommand(_ sender: NSMenuItem) {
        guard let method = sender.representedObject as? String else { return }
        channel?.invokeMethod(method, arguments: nil)
    }

    @objc fileprivate func onServer(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        channel?.invokeMethod("server", arguments: id)
    }
}

/// One server's row: a dot and a name, a sparkline, and the readings.
///
/// A view rather than a title because a title is one line of one font. What is
/// wanted is two lines and a chart, and `NSMenuItem.view` is the supported way
/// to have them.
///
/// Drawing it by hand rather than stacking `NSTextField`s: this is repainted
/// whenever the menu highlights a row, and a handful of `draw(_:)` calls is
/// less machinery than a view tree that has to be kept in step with a
/// highlight.
@available(macOS 10.15, *)
private final class TrayRowView: NSView {
    private let name: String
    private let state: String
    private let readings: [(String, String)]
    private let chart: [Double]
    private weak var item: NSMenuItem?

    /// What a menu item's own text lines up with. `NSMenu` has no public
    /// metric for it, and 14 is what the system uses at every size the menu
    /// bar offers — checked against a plain item beside this one.
    private static let dotSize: CGFloat = 7
    private static let leading: CGFloat = 14
    private static let trailing: CGFloat = 12
    private static let chartWidth: CGFloat = 60
    private static let chartHeight: CGFloat = 18
    private static let padding: CGFloat = 5
    private static let lineGap: CGFloat = 1

    private static let nameFont = NSFont.menuFont(ofSize: 0)
    private static let detailFont = NSFont.monospacedDigitSystemFont(
        ofSize: NSFont.smallSystemFontSize, weight: .regular
    )

    /// Measured from the fonts rather than picked: a menu font follows a
    /// system setting, and a row sized by hand goes wrong the moment somebody
    /// changes it.
    private static func height(hasDetail: Bool) -> CGFloat {
        let name = nameFont.boundingRectForFont.height
        guard hasDetail else { return ceil(name + padding * 2) }
        let detail = detailFont.boundingRectForFont.height
        return ceil(name + lineGap + detail + padding * 2)
    }

    init(line: [String: Any], item: NSMenuItem) {
        self.name = line["name"] as? String ?? ""
        self.state = line["state"] as? String ?? "offline"
        self.readings = (line["readings"] as? [[String: Any]] ?? []).map {
            ($0["label"] as? String ?? "", $0["value"] as? String ?? "")
        }
        self.chart = (line["chart"] as? [Double]) ?? []
        self.item = item
        super.init(frame: NSRect(
            x: 0, y: 0, width: 260,
            height: Self.height(hasDetail: !readings.isEmpty)
        ))
        autoresizingMask = [.width]
    }

    required init?(coder: NSCoder) { fatalError() }

    /// The colour of the dot. Only the failure is coloured: the rest read as
    /// ordinary text, and a menu where every row is coloured is one where the
    /// colour has stopped meaning anything.
    private var dotColour: NSColor {
        switch state {
        case "ok": return .systemGreen
        case "working": return .systemOrange
        case "failed": return .systemRed
        default: return .tertiaryLabelColor
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        let highlighted = item?.isHighlighted ?? false
        if highlighted {
            // The accent colour and not `selectedMenuItemColor`, which is
            // deprecated in favour of a visual-effect material — a whole
            // backing view for one filled rectangle.
            NSColor.selectedContentBackgroundColor.setFill()
            bounds.fill()
        }

        let primary = highlighted ? NSColor.alternateSelectedControlTextColor : NSColor.labelColor
        let secondary = highlighted
            ? NSColor.alternateSelectedControlTextColor.withAlphaComponent(0.75)
            : NSColor.secondaryLabelColor

        let nameAttrs: [NSAttributedString.Key: Any] = [
            .font: Self.nameFont, .foregroundColor: primary,
        ]
        let nameSize = (name as NSString).size(withAttributes: nameAttrs)
        let detail = readings.map { "\($0.0) \($0.1)" }.joined(separator: "   ")
        let detailAttrs: [NSAttributedString.Key: Any] = [
            .font: Self.detailFont, .foregroundColor: secondary,
        ]
        let detailSize = detail.isEmpty
            ? .zero
            : (detail as NSString).size(withAttributes: detailAttrs)

        // Laid out from the bottom, which is where this coordinate space
        // starts: the detail sits on the bottom padding and the name above it,
        // so the two keep their gap whatever the fonts measure.
        let detailY = Self.padding
        let nameY = detail.isEmpty
            ? (bounds.height - nameSize.height) / 2
            : detailY + detailSize.height + Self.lineGap

        let textX = Self.leading + Self.dotSize + 7
        (name as NSString).draw(at: NSPoint(x: textX, y: nameY), withAttributes: nameAttrs)
        if !detail.isEmpty {
            (detail as NSString).draw(
                at: NSPoint(x: textX, y: detailY), withAttributes: detailAttrs
            )
        }

        // Against the name, not against the row: it belongs to the line that
        // names the machine, and centring it over both lines left it floating
        // between them.
        let dot = NSBezierPath(ovalIn: NSRect(
            x: Self.leading,
            y: nameY + (nameSize.height - Self.dotSize) / 2,
            width: Self.dotSize, height: Self.dotSize
        ))
        (highlighted ? primary : dotColour).setFill()
        dot.fill()

        if !chart.isEmpty {
            drawChart(
                in: NSRect(
                    x: bounds.maxX - Self.trailing - Self.chartWidth,
                    y: (bounds.height - Self.chartHeight) / 2,
                    width: Self.chartWidth, height: Self.chartHeight
                ),
                colour: highlighted ? primary : NSColor.controlAccentColor
            )
        }
    }

    /// The series, already 0…1 and oldest first.
    ///
    /// Filled under the line as well as stroked: at 14 points tall a line alone
    /// is a thread, and the area is what makes the shape readable at a glance —
    /// which is the whole reason the chart is here rather than a number.
    private func drawChart(in rect: NSRect, colour: NSColor) {
        guard chart.count > 1 else { return }
        let step = rect.width / CGFloat(chart.count - 1)
        let path = NSBezierPath()
        for (i, value) in chart.enumerated() {
            let point = NSPoint(
                x: rect.minX + CGFloat(i) * step,
                y: rect.minY + CGFloat(max(0, min(1, value))) * rect.height
            )
            if i == 0 { path.move(to: point) } else { path.line(to: point) }
        }

        let area = path.copy() as! NSBezierPath
        area.line(to: NSPoint(x: rect.maxX, y: rect.minY))
        area.line(to: NSPoint(x: rect.minX, y: rect.minY))
        area.close()
        colour.withAlphaComponent(0.18).setFill()
        area.fill()

        colour.setStroke()
        path.lineWidth = 1.2
        path.stroke()
    }

    /// A view in a menu item gets the clicks, and the item's own action does
    /// not fire. So the row sends it on and closes the menu, which is what
    /// clicking a menu item does.
    override func mouseUp(with event: NSEvent) {
        guard let item else { return }
        item.menu?.cancelTracking()
        if let target = item.target as? TrayIcon {
            target.onServer(item)
        }
    }

    /// Highlighting is drawn by the item for an ordinary row and by the view
    /// for this one, so it has to be repainted as the pointer moves.
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.acceptsMouseMovedEvents = true
    }

    override func mouseEntered(with event: NSEvent) { needsDisplay = true }
    override func mouseExited(with event: NSEvent) { needsDisplay = true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self
        ))
    }
}
