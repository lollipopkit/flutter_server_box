//
//  StatusWidget.swift
//  StatusWidget
//
//  Created by lolli on 2023/7/15.
//

import WidgetKit
import SwiftUI
import Intents
import AppIntents
import Foundation

let demoStatus = Status(name: "Server", cpu: "31.7%", mem: "1.3g / 1.9g", disk: "7.1g / 30.0g", net: "712.3k / 1.2m")
let domain = "com.lollipopkit.toolbox"
let bgColor = DynamicColor(dark: UIColor.black, light: UIColor.white)

struct Provider: IntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: ConfigurationIntent(), state: .normal(demoStatus))
    }

    func getSnapshot(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), configuration: configuration, state: .normal(demoStatus))
        completion(entry)
    }

    func getTimeline(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        var url = configuration.url
        
        let family = context.family
        if #available(iOSApplicationExtension 16.0, *) {
            if family == .accessoryInline || family == .accessoryRectangular {
                url = UserDefaults.standard.string(forKey: accessoryKey)
            }
        }

        let currentDate = Date()
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
        fetch(url: url) { result in
            let entry: SimpleEntry = SimpleEntry(
                date: currentDate,
                configuration: configuration,
                state: result
            )
            let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
            completion(timeline)
        }
    }
    
    func fetch(url: String?, completion: @escaping (ContentState) -> Void) {
        guard let url = url, url.count >= 12 else {
            completion(.error(.url("url is nil OR len < 12")))
            return
        }
        guard let url = URL(string: url) else {
            completion(.error(.url("parse url failed")))
            return
        }

        let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
            if error != nil {
                completion(.error(.http(error?.localizedDescription ?? "unknown http err")))
                return
            }
            guard let data = data else {
                completion(.error(.http("empty http data")))
                return
            }
            let jsonAll = try! JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] ?? [:]
            let code = jsonAll["code"] as? Int ?? 1
            if (code != 0) {
                let msg = jsonAll["msg"] as? String ?? "Empty err"
                completion(.error(.http(msg)))
                return
            }

            let json = jsonAll["data"] as? [String: Any] ?? [:]
            let name = json["name"] as? String ?? ""
            let disk = json["disk"] as? String ?? ""
            let cpu = json["cpu"] as? String ?? ""
            let mem = json["mem"] as? String ?? ""
            let net = json["net"] as? String ?? ""
            completion(.normal(Status(name: name, cpu: cpu, mem: mem, disk: disk, net: net)))
        }
        task.resume()
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationIntent
    let state: ContentState
}

struct StatusWidgetEntryView : View {
    var entry: Provider.Entry

    @Environment(\.widgetFamily) var family: WidgetFamily

    var body: some View {
        switch entry.state {
            case .loading:
                Text("Loading").widgetBackground()
            case .error(let err):
                switch err {
                case .http(let description):
                    VStack(alignment: .center) {
                        Text(description)
                        if #available(iOS 17.0, *) {
                            Button(intent: RefreshIntent()) {
                                Image(systemName: "arrow.clockwise")
                                    .resizable()
                                    .frame(width: 10, height: 12.7)
                            }.tint(.gray)
                        }
                    }
                    .widgetBackground()
                case .url(_):
                    Link("Open wiki ⬅️", destination: helpUrl)
                    .widgetBackground()
                }
            case .normal(let data):
                let sumColor: Color = .primary.opacity(0.7)
                switch family {
                    case .accessoryRectangular:
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(data.name)
                                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                                Spacer()
                                CirclePercent(percent: data.cpu)
                                    .padding(.top, 3)
                                    .padding(.trailing, 3)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            Spacer()
                            DetailItem(icon: "memorychip", text: data.mem, color: sumColor)
                            DetailItem(icon: "externaldrive", text: data.disk, color: sumColor)
                            DetailItem(icon: "network", text: data.net, color: sumColor)
                        }
                        .widgetBackground()
                    case .accessoryInline:
                        Text("\(data.name) \(data.cpu)").widgetBackground()
                    default:
                        VStack(alignment: .leading, spacing: 3.7) {
                            if #available(iOS 17.0, *) {
                                HStack {
                                    Text(data.name).font(.system(.title3, design: .monospaced))
                                    Spacer()
                                    Button(intent: RefreshIntent()) {
                                        Image(systemName: "arrow.clockwise")
                                            .resizable()
                                            .frame(width: 10, height: 12.7)
                                    }.tint(.gray)
                                }
                            } else {
                                Text(data.name).font(.system(.title3, design: .monospaced))
                            }
                            Spacer()
                            DetailItem(icon: "cpu", text: data.cpu, color: sumColor)
                            DetailItem(icon: "memorychip", text: data.mem, color: sumColor)
                            DetailItem(icon: "externaldrive", text: data.disk, color: sumColor)
                            DetailItem(icon: "network", text: data.net, color: sumColor)
                            Spacer()
                            DetailItem(icon: "clock", text: entry.date.toStr(), color: sumColor)
                                .padding(.bottom, 3)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .autoPadding()
                        .widgetBackground()
                }
        }
    }
}

extension View {
    @ViewBuilder
    func widgetBackground() -> some View {
        // Set bg to black in Night, white in Day
        let backgroundView = Color(bgColor.resolve())
        if #available(iOS 17.0, *) {
            containerBackground(for: .widget) {
                backgroundView
            }
        } else {
            background(backgroundView)
        }
    }
    
    // iOS 17 will auto add a SafeArea, so when iOS < 17, add .padding(.all, 17)
    func autoPadding() -> some View {
        if #available(iOS 17.0, *) {
            return self
        } else {
            return self.padding(.all, 17)
        }
    }
}

struct StatusWidget: Widget {
    let kind: String = "StatusWidget"

    var body: some WidgetConfiguration {
        let cfg = IntentConfiguration(kind: kind, intent: ConfigurationIntent.self, provider: Provider()) { entry in
            StatusWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Status")
        .description("Status of your servers.")
        if #available(iOSApplicationExtension 16.0, *) {            
            return cfg.supportedFamilies([.systemSmall, .accessoryRectangular, .accessoryInline])
        } else {
            return cfg.supportedFamilies([.systemSmall])
        }
    }
}

struct StatusWidget_Previews: PreviewProvider {
    static var previews: some View {
        StatusWidgetEntryView(entry: SimpleEntry(date: Date(), configuration: ConfigurationIntent(), state: .normal(demoStatus)))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
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

// 空心圆，显示百分比
struct CirclePercent: View {
    // eg: 31.7%
    let percent: String
    
    var body: some View {
        // 31.7% -> 0.317
        let percentD = Double(percent.trimmingCharacters(in: .init(charactersIn: "%")))
        let double = (percentD ?? 0) / 100
        Circle()
            .trim(from: 0, to: CGFloat(double))
            .stroke(Color.primary, lineWidth: 3)
            .animation(.easeInOut(duration: 0.5))
    }
}

struct DynamicColor {
    let dark: UIColor
    let light: UIColor
    
    func resolve() -> UIColor {
        if #available(iOS 13, *) {  // 版本号大于等于13
            return UIColor { (traitCollection: UITraitCollection) -> UIColor in
                return traitCollection.userInterfaceStyle == UIUserInterfaceStyle.dark ?
                    self.dark : self.light
            }
        }
        return self.light
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct RefreshIntent: AppIntent {
    static var title: LocalizedStringResource = "Refresh"
    static var description = IntentDescription("Refresh status.")
    
    func perform() async throws -> some IntentResult {
        return .result()
    }
}
