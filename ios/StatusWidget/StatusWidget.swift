//
//  StatusWidget.swift
//  StatusWidget
//
//  Created by lolli on 2023/7/15.
//

import WidgetKit
import SwiftUI
import Intents

let demoStatus = Status(name: "Server", cpu: "31.7%", mem: "1.3g / 1.9g", disk: "7.1g / 30.0g", net: "712.3k / 1.2m")
let domain = "com.lollipopkit.toolbox"
var url: String?

struct Provider: IntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: ConfigurationIntent(), state: .normal(demoStatus))
    }

    func getSnapshot(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), configuration: configuration, state: .normal(demoStatus))
        completion(entry)
    }

    func getTimeline(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        url = configuration.url

        let currentDate = Date()
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 30, to: currentDate)!
        StatusLoader.fetch { result in
            let entry: SimpleEntry
            switch result {
            case .success(let status):
                entry = SimpleEntry(
                    date: currentDate,
                    configuration: configuration,
                    state: .normal(status)
                )
            case .failure(let err):
                entry = SimpleEntry(date: currentDate, configuration: configuration, state: .error(err.localizedDescription))
            }
            let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
            completion(timeline)
        }
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationIntent
    let state: ContentState
}

struct StatusWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        switch entry.state {
            case .loading:
                ProgressView().padding()
            case .error(let descriotion):
                Text(descriotion).padding(.all, 13)
            case .normal(let data):
                let sumColor: Color = .primary.opacity(0.7)
                VStack(alignment: .leading, spacing: 3.7) {
                    Text(data.name).font(.system(.title3, design: .monospaced))
                    Spacer()
                    DetailItem(icon: "cpu", text: data.cpu, color: sumColor)
                    DetailItem(icon: "memorychip", text: data.mem, color: sumColor)
                    DetailItem(icon: "externaldrive", text: data.disk, color: sumColor)
                    DetailItem(icon: "network", text: data.net, color: sumColor)
                    Spacer()
                    DetailItem(icon: "clock", text: entry.date.toStr(), color: sumColor)
                }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.all, 17)
        }
    }
}

struct StatusWidget: Widget {
    let kind: String = "StatusWidget"

    var body: some WidgetConfiguration {
        IntentConfiguration(kind: kind, intent: ConfigurationIntent.self, provider: Provider()) { entry in
            StatusWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Status")
        .description("Status of your servers.")
        .supportedFamilies([.systemSmall])
    }
}

struct StatusWidget_Previews: PreviewProvider {
    static var previews: some View {
        StatusWidgetEntryView(entry: SimpleEntry(date: Date(), configuration: ConfigurationIntent(), state: .normal(demoStatus)))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}

struct StatusLoader {
    static func fetch(completion: @escaping (Result<Status, Error>) -> Void) {
        guard let url = url, url.count >= 12 else {
            completion(.failure(NSError(domain: domain, code: 0, userInfo: [NSLocalizedDescriptionKey: "https://github.com/lollipopkit/server_box_monitor/wiki"])))
            return
        }
        guard let url = URL(string: url) else {
            completion(.failure(NSError(domain: domain, code: 1, userInfo: [NSLocalizedDescriptionKey: "url is invalid"])))
            return
        }
        let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
            if error != nil {
                completion(.failure(error!))
                return
            }
            guard let data = data else {
                completion(.failure(NSError(domain: domain, code: 2, userInfo: [NSLocalizedDescriptionKey: "empty network data."])))
                return
            }
            switch getStatus(fromData: data) {
            case .success(let status):
                completion(.success(status))
            case .failure(let error):
                completion(.failure(error))
            }
        }
        task.resume()
    }

    static func getStatus(fromData data: Foundation.Data) -> Result<Status, Error> {
        let jsonAll = try! JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] ?? [:]
        let code = jsonAll["code"] as? Int ?? 1
        if (code != 0) {
            switch (code) {
            default:
                let msg = jsonAll["msg"] as? String ?? ""
                return .failure(NSError(domain: domain, code: code, userInfo: [NSLocalizedDescriptionKey: msg]))
            }
        }

        let json = jsonAll["data"] as? [String: Any] ?? [:]
        let name = json["name"] as? String ?? ""
        let disk = json["disk"] as? String ?? ""
        let cpu = json["cpu"] as? String ?? ""
        let mem = json["mem"] as? String ?? ""
        let net = json["net"] as? String ?? ""
        return .success(Status(name: name, cpu: cpu, mem: mem, disk: disk, net: net))
    }
}

struct DetailItem: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 6.7) {
            Image(systemName: icon).resizable().foregroundColor(color).frame(width: 11, height: 11, alignment: .center)
            Text(text)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(color)
        }
    }
}
