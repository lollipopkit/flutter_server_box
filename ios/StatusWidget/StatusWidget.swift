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

// Widget-specific constants
enum WidgetConstants {
    enum Dimensions {
        static let smallGauge: CGFloat = 56
        static let mediumGauge: CGFloat = 64
        static let largeGauge: CGFloat = 76
        static let refreshIconSmall: CGFloat = 12
        static let refreshIconLarge: CGFloat = 14
        static let cornerRadius: CGFloat = 12
        static let shadowRadius: CGFloat = 2
    }
    enum Thresholds {
        static let warningThreshold: Double = 0.6
        static let criticalThreshold: Double = 0.85
    }
    enum Spacing {
        static let tight: CGFloat = 4
        static let normal: CGFloat = 8
        static let loose: CGFloat = 12
        static let extraLoose: CGFloat = 16
    }
    enum Colors {
        static let cardBackground = Color(.systemBackground)
        static let secondaryText = Color(.secondaryLabel)
        static let success = Color(.systemGreen)
        static let warning = Color(.systemOrange)
        static let critical = Color(.systemRed)
        static let accent = Color(.systemBlue)
    }
    static let appGroupId = "group.com.lollipopkit.toolbox"
}

// Performance optimization: cache parsed values
struct ParseCache {
    private static var percentCache: [String: Double] = [:]
    private static var usagePercentCache: [String: Double] = [:]
    
    static func parsePercent(_ text: String) -> Double {
        if let cached = percentCache[text] { return cached }
        let trimmed = text.trimmingCharacters(in: CharacterSet(charactersIn: "% "))
        let result = Double(trimmed).map { max(0, min(1, $0 / 100.0)) } ?? 0
        percentCache[text] = result
        return result
    }
    
    static func parseUsagePercent(_ text: String) -> Double {
        if let cached = usagePercentCache[text] { return cached }
        let parts = text.split(separator: "/").map { String($0).trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2 else { return 0 }
        let used = PerformanceUtils.parseSizeToBytes(parts[0])
        let total = PerformanceUtils.parseSizeToBytes(parts[1])
        let result = total <= 0 ? 0 : max(0, min(1, used / total))
        usagePercentCache[text] = result
        return result
    }
    
    static func parseNetworkTotal(_ text: String) -> (totalBytes: Double, displayText: String) {
        let parts = text.split(separator: "/").map { String($0).trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2 else { return (0, "0 B") }
        let upload = PerformanceUtils.parseSizeToBytes(parts[0])
        let download = PerformanceUtils.parseSizeToBytes(parts[1])
        let total = upload + download
        let displayText = PerformanceUtils.formatSize(total)
        return (total, displayText)
    }
    
    static func parseNetworkPercent(_ text: String) -> Double {
        let parts = text.split(separator: "/").map { String($0).trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2 else { return 0 }
        let upload = PerformanceUtils.parseSizeToBytes(parts[0])
        let download = PerformanceUtils.parseSizeToBytes(parts[1])
        let total = upload + download
        // Return upload percentage of total traffic
        return total <= 0 ? 0 : max(0, min(1, upload / total))
    }
}

struct PerformanceUtils {
    // Precomputed multipliers for performance
    private static let sizeMultipliers: [Character: Double] = [
        "k": 1024,
        "m": pow(1024, 2),
        "g": pow(1024, 3),
        "t": pow(1024, 4),
        "p": pow(1024, 5)
    ]
    
    static func parseSizeToBytes(_ text: String) -> Double {
        let lower = text.lowercased().replacingOccurrences(of: "b", with: "")
        let unitChar = lower.trimmingCharacters(in: .whitespaces).last
        let numberPart: String
        let multiplier: Double
        
        if let u = unitChar, let mult = sizeMultipliers[u] {
            multiplier = mult
            numberPart = String(lower.dropLast())
        } else {
            multiplier = 1.0
            numberPart = lower
        }
        
        let value = Double(numberPart.trimmingCharacters(in: .whitespaces)) ?? 0
        return value * multiplier
    }
    
    static func percentStr(_ value: Double) -> String {
        let pct = max(0, min(1, value)) * 100
        let rounded = (pct * 10).rounded() / 10
        return rounded.truncatingRemainder(dividingBy: 1) == 0 
            ? String(format: "%.0f%%", rounded)
            : String(format: "%.1f%%", rounded)
    }
    
    static func thresholdColor(_ value: Double) -> Color {
        let v = max(0, min(1, value))
        switch v {
        case ..<WidgetConstants.Thresholds.warningThreshold: return WidgetConstants.Colors.success
        case ..<WidgetConstants.Thresholds.criticalThreshold: return WidgetConstants.Colors.warning
        default: return WidgetConstants.Colors.critical
        }
    }
    
    static func formatSize(_ bytes: Double) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var size = bytes
        var unitIndex = 0
        
        while size >= 1024 && unitIndex < units.count - 1 {
            size /= 1024
            unitIndex += 1
        }
        
        return String(format: "%.1f %@", size, units[unitIndex])
    }
}

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
        #if os(iOS)
        if #available(iOSApplicationExtension 16.0, *) {
            if family == .accessoryInline || family == .accessoryRectangular {
                url = UserDefaults(suiteName: WidgetConstants.appGroupId)?.string(forKey: "accessory_widget_url")
            }
        }
        #endif

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
                                    .frame(width: WidgetConstants.Dimensions.refreshIconSmall, height: WidgetConstants.Dimensions.refreshIconSmall * 1.27)
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
                    case .systemMedium:
                        VStack(alignment: .leading, spacing: WidgetConstants.Spacing.normal) {
                            // Title + refresh
                            if #available(iOS 17.0, *) {
                                HStack {
                                    Text(data.name).font(.system(.title3, design: .monospaced))
                                    Spacer()
                                    Button(intent: RefreshIntent()) {
                                        Image(systemName: "arrow.clockwise")
                                            .resizable()
                                            .frame(width: WidgetConstants.Dimensions.refreshIconSmall, height: WidgetConstants.Dimensions.refreshIconSmall * 1.27)
                                    }.tint(.gray)
                                }
                            } else {
                                Text(data.name).font(.system(.title3, design: .monospaced))
                            }
                            Spacer(minLength: WidgetConstants.Spacing.normal)
                            // Gauges row
                            HStack(spacing: WidgetConstants.Spacing.tight) {
                                GaugeTile(label: "CPU", value: ParseCache.parsePercent(data.cpu), display: data.cpu, diameter: WidgetConstants.Dimensions.smallGauge)
                                GaugeTile(label: "MEM", value: ParseCache.parseUsagePercent(data.mem), display: PerformanceUtils.percentStr(ParseCache.parseUsagePercent(data.mem)), diameter: WidgetConstants.Dimensions.smallGauge)
                                GaugeTile(label: "DISK", value: ParseCache.parseUsagePercent(data.disk), display: PerformanceUtils.percentStr(ParseCache.parseUsagePercent(data.disk)), diameter: WidgetConstants.Dimensions.smallGauge)
                                GaugeTile(label: "NET", value: ParseCache.parseNetworkPercent(data.net), display: ParseCache.parseNetworkTotal(data.net).displayText, diameter: WidgetConstants.Dimensions.smallGauge)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.bottom, 3)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .autoPadding()
                        .widgetBackground()
                    #if os(iOS)
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
                    #endif
                    default:
                        VStack(alignment: .leading, spacing: 3.7) {
                            if #available(iOS 17.0, *) {
                                HStack {
                                    Text(data.name).font(.system(.title3, design: .monospaced))
                                    Spacer()
                                    Button(intent: RefreshIntent()) {
                                        Image(systemName: "arrow.clockwise")
                                            .resizable()
                                            .frame(width: WidgetConstants.Dimensions.refreshIconSmall, height: WidgetConstants.Dimensions.refreshIconSmall * 1.27)
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
        // Modern card-style background with subtle effects
        let backgroundView = LinearGradient(
            gradient: Gradient(colors: [
                Color(bgColor.resolve()),
                Color(bgColor.resolve()).opacity(0.95)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        if #available(iOS 17.0, *) {
            containerBackground(for: .widget) {
                backgroundView
            }
        } else {
            background(backgroundView)
        }
    }
    
    // Enhanced padding with improved spacing
    func autoPadding() -> some View {
        if #available(iOS 17.0, *) {
            return self.padding(.all, WidgetConstants.Spacing.tight)
        } else {
            return self.padding(.all, WidgetConstants.Spacing.extraLoose + 1)
        }
    }
    
    // Modern card container with shadow and rounded corners
    func modernCard(cornerRadius: CGFloat = WidgetConstants.Dimensions.cornerRadius) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(WidgetConstants.Colors.cardBackground)
                    .shadow(
                        color: .black.opacity(0.08),
                        radius: WidgetConstants.Dimensions.shadowRadius,
                        x: 0,
                        y: 1
                    )
            )
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
        #if os(iOS)
        if #available(iOSApplicationExtension 16.0, *) {
            return cfg.supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
        } else {
            return cfg.supportedFamilies([.systemSmall, .systemMedium])
        }
        #else
            return cfg.supportedFamilies([.systemSmall, .systemMedium])
        #endif
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
        HStack(spacing: WidgetConstants.Spacing.normal) {
            Image(systemName: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundColor(color.opacity(0.8))
                .frame(width: 12, height: 12)
                .background(
                    Circle()
                        .fill(color.opacity(0.1))
                        .frame(width: 20, height: 20)
                )
            
            Text(text)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, WidgetConstants.Spacing.tight)
        .padding(.vertical, 2)
    }
}

// Enhanced circular progress indicator
struct CirclePercent: View {
    // eg: 31.7%
    let percent: String
    @State private var animatedProgress: Double = 0
    
    var body: some View {
        let percentD = Double(percent.trimmingCharacters(in: .init(charactersIn: "%")))
        let progress = (percentD ?? 0) / 100
        
        ZStack {
            // Background circle
            Circle()
                .stroke(Color.primary.opacity(0.15), lineWidth: 2.5)
            
            // Progress circle with gradient
            Circle()
                .trim(from: 0, to: CGFloat(max(0, min(1, animatedProgress))))
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            PerformanceUtils.thresholdColor(progress).opacity(0.7),
                            PerformanceUtils.thresholdColor(progress)
                        ]),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            
            // Percentage text
            Text(percent)
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .foregroundColor(.primary.opacity(0.8))
        }
        .frame(width: 24, height: 24)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { newProgress in
            withAnimation(.easeInOut(duration: 0.5)) {
                animatedProgress = newProgress
            }
        }
    }
}

// Modern gauge tile with enhanced visual design
struct GaugeTile: View {
    let label: String
    // 0..1
    let value: Double
    // eg: "31.7%"
    let display: String
    let diameter: CGFloat
    
    @State private var animatedValue: Double = 0
    
    var body: some View {
        VStack(spacing: WidgetConstants.Spacing.normal) {
            ZStack {
                // Background circle with subtle shadow effect
                Circle()
                    .stroke(Color.primary.opacity(0.1), lineWidth: 4)
                    .background(
                        Circle()
                            .fill(WidgetConstants.Colors.cardBackground)
                            .shadow(color: .black.opacity(0.05), radius: WidgetConstants.Dimensions.shadowRadius, x: 0, y: 1)
                    )
                
                // Progress arc with gradient effect
                Circle()
                    .trim(from: 0, to: CGFloat(max(0, min(1, animatedValue))))
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                PerformanceUtils.thresholdColor(value).opacity(0.8),
                                PerformanceUtils.thresholdColor(value)
                            ]),
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                
                // Center value text with improved typography
                Text(display)
                    .font(.system(size: diameter < 60 ? 11 : 13, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
            }
            .frame(width: diameter, height: diameter)
            .onAppear {
                withAnimation(.easeOut(duration: 0.8).delay(0.1)) {
                    animatedValue = value
                }
            }
            .onChange(of: value) { newValue in
                withAnimation(.easeInOut(duration: 0.6)) {
                    animatedValue = newValue
                }
            }
            
            // Label with enhanced styling
            if #available(iOS 16.0, *) {
                Text(label)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(WidgetConstants.Colors.secondaryText)
                    .textCase(.uppercase)
                    .tracking(0.5)
            } else {
                Text(label)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(WidgetConstants.Colors.secondaryText)
                    .textCase(.uppercase)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// Legacy functions maintained for compatibility - now delegate to optimized versions
func parsePercent(_ text: String) -> Double {
    return ParseCache.parsePercent(text)
}

func parseUsagePercent(_ text: String) -> Double {
    return ParseCache.parseUsagePercent(text)
}

func parseSizeToBytes(_ text: String) -> Double {
    return PerformanceUtils.parseSizeToBytes(text)
}

func percentStr(_ value: Double) -> String {
    return PerformanceUtils.percentStr(value)
}

func thresholdColor(_ value: Double) -> Color {
    return PerformanceUtils.thresholdColor(value)
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
