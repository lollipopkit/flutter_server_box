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
/// means different things in different families — see [fits]. Anything past
/// one chart needs a medium widget, and a small one asked for more says so
/// rather than quietly drawing something else.
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

    /// How many charts this draws.
    var chartCount: Int {
        switch self {
        case .text: return 0
        case .oneChart: return 1
        case .twoCharts: return 2
        case .fourCharts: return 4
        }
    }

    /// Whether [family] has room for it.
    ///
    /// A small widget is about the size of an app icon: two charts in it are
    /// two smudges, so anything past one needs a medium.
    ///
    /// It used to narrow silently — four charts on a small widget quietly
    /// became one. That reads as the setting having no effect, and there is
    /// nowhere in a widget to notice otherwise. Saying so and drawing nothing
    /// is the honest answer: the fix is one gesture away, and the widget is
    /// the only place to mention it.
    func fits(_ family: WidgetFamily) -> Bool {
        switch family {
        case .systemSmall: return chartCount <= 1
        default: return true
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
