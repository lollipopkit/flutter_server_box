//
//  WatchStatusWidget.swift
//  WatchStatusWidget Extension
//
//  Created by AI Assistant
//

import WidgetKit
import SwiftUI
import Foundation

// Simple model, independent from Runner target
struct Status: Hashable {
    let name: String
    let cpu: String
    let mem: String
    let disk: String
    let net: String
}

struct WatchProvider: TimelineProvider {
    func placeholder(in context: Context) -> WatchEntry {
        WatchEntry(date: Date(), status: Status(name: "Server", cpu: "32%", mem: "1.3g/1.9g", disk: "7.1g/30g", net: "712k/1.2m"))
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchEntry>) -> Void) {
        let entry = loadEntry()
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func loadEntry() -> WatchEntry {
        let appGroupId = "group.com.lollipopkit.toolbox"
        guard let defaults = UserDefaults(suiteName: appGroupId) else {
            return WatchEntry(date: Date(), status: Status(name: "Server", cpu: "--%", mem: "-", disk: "-", net: "-"))
        }
        
        let urls = (defaults.array(forKey: "watch_shared_urls") as? [String]) ?? []
        let idx = defaults.integer(forKey: "watch_shared_selected_index")
        var status: Status? = nil
        
        if !urls.isEmpty {
            let i = min(max(0, idx), urls.count - 1)
            let url = urls[i]
            
            // Load status from shared defaults
            if let statusMap = defaults.dictionary(forKey: "watch_shared_status_by_url") as? [String: [String: String]],
               let statusDict = statusMap[url] {
                status = Status(
                    name: statusDict["name"] ?? "",
                    cpu: statusDict["cpu"] ?? "",
                    mem: statusDict["mem"] ?? "",
                    disk: statusDict["disk"] ?? "",
                    net: statusDict["net"] ?? ""
                )
            }
        }
        return WatchEntry(
            date: Date(),
            status: status ?? Status(name: "Server", cpu: "--%", mem: "-", disk: "-", net: "-")
        )
    }
}

struct WatchEntry: TimelineEntry {
    let date: Date
    let status: Status
}

struct WatchStatusWidgetEntryView: View {
    var entry: WatchProvider.Entry

    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                Circle().stroke(Color.primary.opacity(0.15), lineWidth: 4)
                CirclePercent(percent: entry.status.cpu)
                Text(entry.status.cpu.replacingOccurrences(of: "%", with: "")).font(.system(size: 10, weight: .bold, design: .monospaced))
            }
            .padding(2)
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(entry.status.name).font(.system(size: 12, weight: .semibold, design: .monospaced))
                    Spacer()
                }
                HStack(spacing: 6) {
                    Label(entry.status.cpu, systemImage: "cpu").font(.system(size: 11, design: .monospaced))
                }
            }
        case .accessoryInline:
            Text("\(entry.status.name) \(entry.status.cpu)")
        default:
            VStack {
                Text(entry.status.name)
                Text(entry.status.cpu)
            }
        }
    }
}

struct WatchStatusWidget: Widget {
    let kind: String = "WatchStatusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchProvider()) { entry in
            WatchStatusWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Server Status")
        .description("Shows the selected server status.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct WatchStatusWidget_Previews: PreviewProvider {
    static var previews: some View {
        WatchStatusWidgetEntryView(entry: WatchEntry(date: Date(), status: Status(name: "Server", cpu: "37%", mem: "1.3g/1.9g", disk: "7.1g/30g", net: "712k/1.2m")))
            .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
    }
}

// Helpers reused from iOS widget with lightweight versions
struct CirclePercent: View {
    let percent: String
    var body: some View {
        let percentD = Double(percent.trimmingCharacters(in: .init(charactersIn: "% "))) ?? 0
        let p = max(0, min(100, percentD)) / 100.0
        Circle()
            .trim(from: 0, to: CGFloat(p))
            .stroke(Color.primary, style: StrokeStyle(lineWidth: 4, lineCap: .round))
            .rotationEffect(.degrees(-90))
    }
}

