//
//  WidgetIntent.swift
//  StatusWidget
//
//  What the user picks when they add the widget, and where the choices come
//  from.
//
//  This replaces a `.intentdefinition` whose only parameter was a free-text
//  URL. That URL pointed at the agent's unauthenticated compat endpoint, which
//  answers preformatted strings and no history — so the widget could never
//  draw a trend, and configuring it meant typing an address the app already
//  knew. Picking from the app's own server list is the point of the rewrite;
//  needing `AppIntentConfiguration` for it is why this target is iOS 17.
//

import AppIntents
import WidgetKit

/// One server, as the configuration sheet's picker sees it.
struct MonitorServerEntity: AppEntity {
    let id: String
    let name: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Server")
    }

    static var defaultQuery = MonitorServerQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

/// Answers the picker from what the app published into the App Group.
///
/// No network, and deliberately: this runs while someone is looking at a
/// configuration sheet, and a list that takes a round trip per server to
/// assemble would be empty for as long as the slowest agent takes to answer —
/// or forever, on a phone away from home.
struct MonitorServerQuery: EntityQuery {
    func entities(for identifiers: [MonitorServerEntity.ID]) async throws -> [MonitorServerEntity] {
        let wanted = Set(identifiers)
        return WidgetStore.servers()
            .filter { wanted.contains($0.id) }
            .map { MonitorServerEntity(id: $0.id, name: $0.name) }
    }

    func suggestedEntities() async throws -> [MonitorServerEntity] {
        WidgetStore.servers().map { MonitorServerEntity(id: $0.id, name: $0.name) }
    }

    /// What a freshly added widget shows before anything is picked.
    ///
    /// The first server rather than nothing: a widget that says "not
    /// configured" until tapped is indistinguishable from one that is broken,
    /// and someone with a single server never had a choice to make.
    func defaultResult() async -> MonitorServerEntity? {
        try? await suggestedEntities().first
    }
}

/// One reading a widget can lead with.
enum WidgetMetric: String, AppEnum {
    case cpu
    case memory
    case disk
    case network

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Metric")
    }

    static var caseDisplayRepresentations: [WidgetMetric: DisplayRepresentation] = [
        .cpu: "CPU",
        .memory: "Memory",
        .disk: "Disk",
        .network: "Network",
    ]

    /// The order charts fill a widget in, starting from whichever was chosen.
    static let rotation: [WidgetMetric] = [.cpu, .memory, .disk, .network]

    /// [count] metrics beginning at this one, wrapping around.
    func following(_ count: Int) -> [WidgetMetric] {
        guard let start = Self.rotation.firstIndex(of: self) else { return Self.rotation }
        return (0 ..< min(count, Self.rotation.count)).map {
            Self.rotation[(start + $0) % Self.rotation.count]
        }
    }
}

/// How much of the widget is given to charts rather than to numbers.
///
/// Named by what it produces rather than by a size, because the same choice
/// means different things in different families and the widget clamps it —
/// see `WidgetLayout.resolved(for:)`. A user who picks four charts and then
/// resizes to small gets one, not an unreadable grid.
enum WidgetLayout: String, AppEnum {
    /// Readings as text. The only thing that fits a small widget legibly when
    /// more than one number is wanted.
    case text
    case oneChart
    case twoCharts
    case fourCharts

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Layout")
    }

    static var caseDisplayRepresentations: [WidgetLayout: DisplayRepresentation] = [
        .text: "Readings",
        .oneChart: "One chart",
        .twoCharts: "Two charts",
        .fourCharts: "Four charts",
    ]

    /// What this layout becomes at [family].
    ///
    /// A small widget is about the size of an app icon: two charts in it are
    /// two smudges. A medium one is that shape twice over, so it holds two
    /// side by side but not four. Rather than hiding the choice per family —
    /// which would make the sheet's options depend on a size the user can
    /// change afterwards — the choice is kept whole and narrowed here, so
    /// resizing back up restores what was asked for.
    func resolved(for family: WidgetFamily) -> WidgetLayout {
        switch family {
        case .systemSmall:
            return self == .text ? .text : .oneChart
        case .systemMedium:
            switch self {
            case .text: return .text
            case .oneChart: return .oneChart
            case .twoCharts, .fourCharts: return .twoCharts
            }
        default:
            return self
        }
    }
}

struct SelectServerIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Server Status"
    static var description = IntentDescription("Pick a server configured in the app.")

    @Parameter(title: "Server")
    var server: MonitorServerEntity?

    @Parameter(title: "Layout", default: .text)
    var layout: WidgetLayout

    @Parameter(title: "Leading metric", default: .cpu)
    var metric: WidgetMetric
}
