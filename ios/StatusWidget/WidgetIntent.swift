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

/// What a widget is pointed at.
///
/// Which server, and which metric leads — nothing about *what* is drawn. That
/// is the widget's own identity now: the small one shows readings and the
/// medium one shows a chart per metric, and there are two of them so that the
/// choice is made where a widget is picked rather than in a sheet afterwards.
/// A layout setting the size could overrule was a setting that appeared to do
/// nothing.
struct SelectServerIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Server Status"
    static var description = IntentDescription("Pick a server configured in the app.")

    @Parameter(title: "Server")
    var server: MonitorServerEntity?

    /// Which chart leads on the medium widget, and which reading the lock
    /// screen families show — the one place a single metric has to be named.
    @Parameter(title: "Leading metric", default: .cpu)
    var metric: WidgetMetric
}
