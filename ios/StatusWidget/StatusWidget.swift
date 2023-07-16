//
//  StatusWidget.swift
//  StatusWidget
//
//  Created by lolli on 2023/7/15.
//

import WidgetKit
import SwiftUI
import Intents

struct Status {
    let name: String
    let cpu: String
    let mem: String
    let disk: String
    let net: String
}

let demoStatus = Status(name: "Server Name", cpu: "31.7%", mem: "1.3g / 1.9g", disk: "7.1g / 30.0g", net: "712.3k / 1.2m")
let domain = "com.lollipopkit.toolbox"
var url: String?

struct Provider: IntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: ConfigurationIntent(), data: demoStatus, state: .normal)
    }

    func getSnapshot(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), configuration: configuration, data: demoStatus, state: .normal)
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
                    data: status,
                    state: .normal
                )
            case .failure(let err):
                entry = SimpleEntry(date: currentDate, configuration: configuration, data: demoStatus, state: .error(err.localizedDescription))
            }
            let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
            completion(timeline)
        }
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationIntent
    let data: Status
    let state: ContentState
}

struct StatusWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        switch entry.state {
            case .loading:
                ProgressView().padding()
            case .error(let descriotion):
                Text(descriotion)
            case .normal:
                VStack(alignment: .leading, spacing: 5.7) {
                    Text(entry.data.name).font(.system(.title3))
                    Spacer()
                    DetailItem(icon: "cpu", text: entry.data.cpu, color: .primary.opacity(0.7))
                    DetailItem(icon: "memorychip", text: entry.data.mem, color: .primary.opacity(0.7))
                    DetailItem(icon: "externaldrive", text: entry.data.disk, color: .primary.opacity(0.7))
                    Spacer()
                    DetailItem(icon: "clock", text: date2String(entry.date, dateFormat: "HH:mm"), color: .primary.opacity(0.7))
                }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding()
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
        StatusWidgetEntryView(entry: SimpleEntry(date: Date(), configuration: ConfigurationIntent(), data: demoStatus, state: .normal))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}

struct StatusLoader {
    static func fetch(completion: @escaping (Result<Status, Error>) -> Void) {
        if url == nil || url == "" {
            completion(.failure(NSError(domain: domain, code: 1, userInfo: [NSLocalizedDescriptionKey: "Please longpress it to config first."])))
            return
        }
        let URL = URL(string: url!)!
        let task = URLSession.shared.dataTask(with: URL) { (data, response, error) in
            guard error == nil else {
                completion(.failure(error!))
                return
            }
            guard data != nil else {
                completion(.failure(NSError(domain: domain, code: 2, userInfo: [NSLocalizedDescriptionKey: "empty network data."])))
                return
            }
            let result = getStatus(fromData: data!) 
            switch result {
            case .success(let status):
                completion(.success(status))
            case .failure(let error):
                completion(.failure(error))
            }
        }
        task.resume()
    }

    static func getStatus(fromData data: Foundation.Data) -> Result<Status, Error> {

        let jsonAll = try! JSONSerialization.jsonObject(with: data, options: []) as! [String: Any]
        let code = jsonAll["code"] as! Int
        if (code != 0) {
            switch (code) {
            default:
                let msg = jsonAll["msg"] as! String? ?? ""
                return .failure(NSError(domain: domain, code: code, userInfo: [NSLocalizedDescriptionKey: msg]))
            }
        }

        let json = jsonAll["data"] as! [String: Any]
        let name = json["name"] as! String
        let disk = json["disk"] as! String
        let cpu = json["cpu"] as! String
        let mem = json["mem"] as! String
        let net = json["net"] as! String
        return .success(Status(name: name, cpu: cpu, mem: mem, disk: disk, net: net))
    }
}

private func dynamicUIColor(color: DynamicColor) -> UIColor {
    if #available(iOS 13, *) {  // 版本号大于等于13
  return UIColor { (traitCollection: UITraitCollection) -> UIColor in
    return traitCollection.userInterfaceStyle == UIUserInterfaceStyle.dark ?
      color.dark : color.light
  }
}
    return color.light
}

struct DynamicColor {
    let dark: UIColor
    let light: UIColor
}

let bgColor = DynamicColor(dark: UIColor(.black), light: UIColor(.white))
let textColor = DynamicColor(dark: UIColor(.white), light: UIColor(.black))

private func dynamicColor(color: DynamicColor) -> Color {
    return Color.init(dynamicUIColor(color: color))
}

struct DetailItem: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 5.7) {
            Image(systemName: icon).resizable().foregroundColor(color).frame(width: 11, height: 11, alignment: .center)
            Text(text)
                .font(.system(.caption2))
                .foregroundColor(color)
        }
    }
}

func date2String(_ date:Date, dateFormat:String = "yyyy-MM-dd HH:mm:ss") -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale.init(identifier: "zh_CN")
    formatter.dateFormat = dateFormat
    let date = formatter.string(from: date)
    return date
}

enum ContentState {
    case loading
    case error(String)
    case normal
}
