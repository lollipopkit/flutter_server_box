//
//  ContentView.swift
//  WatchEnd Watch App
//
//  Created by lolli on 2023/9/16.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var _mgr = PhoneConnMgr()
    @State private var selection: Int = 0
    @State private var refreshAllCounter: Int = 0
    
    var body: some View {
        let hasServers = !_mgr.urls.isEmpty
        let pagesCount = hasServers ? _mgr.urls.count : 1
        TabView(selection: $selection) {
            ForEach(0 ..< pagesCount, id:\.self) { index in
                let url = hasServers ? _mgr.urls[index] : nil
                PageView(
                    url: url,
                    state: .loading,
                    refreshAllCounter: refreshAllCounter,
                    onRefreshAll: { refreshAllCounter += 1 }
                )
                .tag(index)
            }
        }
        .tabViewStyle(PageTabViewStyle())
        // 当 URL 列表变化时，尽量保持当前选中的页面不变
        .onChange(of: _mgr.urls) { newValue in
            let newCount = newValue.count
            // 当没有服务器时，只有占位页
            if newCount == 0 {
                selection = 0
            } else if selection >= newCount {
                // 如果当前选择超出范围，则跳到最后一个有效页
                selection = max(0, newCount - 1)
            }
        }
        // 持久化当前选择，供 Widget 使用
        .onChange(of: selection) { newIndex in
            let appGroupId = "group.com.lollipopkit.toolbox"
            if let defaults = UserDefaults(suiteName: appGroupId) {
                defaults.set(newIndex, forKey: "watch_shared_selected_index")
            }
        }
        .onAppear {
            // 尽量恢复上一次的选择
            let appGroupId = "group.com.lollipopkit.toolbox"
            let saved = UserDefaults(suiteName: appGroupId)?.integer(forKey: "watch_shared_selected_index") ?? 0
            if !_mgr.urls.isEmpty {
                selection = min(max(0, saved), _mgr.urls.count - 1)
            } else {
                selection = 0
            }
        }
    }
}

struct PageView: View {
    let url: String?
    @State var state: ContentState
    // 触发所有页面刷新的计数器
    let refreshAllCounter: Int
    let onRefreshAll: () -> Void
    
    var body: some View {
        if url == nil {
            VStack {
                Spacer()
                Image(systemName: "exclamationmark.triangle.fill")
                Spacer()
                Text("Tip: Config it in the iOS app settings.").font(.system(.body, design: .monospaced)).padding(.horizontal, 7)
                Spacer()
            }
        } else {
            Group {
                switch state {
                case .loading:
                    ProgressView().padding().onAppear {
                        getStatus(url: url!)
                    }
                case .error(let err):
                switch err {
                case .http(let description):
                    VStack(alignment: .center) {
                        Text(description)
                        HStack(spacing: 10) {
                            Button(action: {
                                state = .loading
                            }){
                                Image(systemName: "arrow.clockwise")
                            }.buttonStyle(.plain)
                            Button(action: {
                                onRefreshAll()
                            }){
                                Image(systemName: "arrow.triangle.2.circlepath")
                            }.buttonStyle(.plain)
                        }
                    }
                case .url(_):
                    Link("View help", destination: helpUrl)
                }
                case .normal(let status):
                    VStack(alignment: .leading) {
                    HStack {
                        Text(status.name).font(.system(.title, design: .monospaced))
                        Spacer()
                        HStack(spacing: 10) {
                            Button(action: {
                                state = .loading
                            }){
                                Image(systemName: "arrow.clockwise")
                            }.buttonStyle(.plain)
                            Button(action: {
                                onRefreshAll()
                            }){
                                Image(systemName: "arrow.triangle.2.circlepath")
                            }.buttonStyle(.plain)
                        }
                    }
                    Spacer()
                    DetailItem(icon: "cpu", text: status.cpu)
                    DetailItem(icon: "memorychip", text: status.mem)
                    DetailItem(icon: "externaldrive", text: status.disk)
                    DetailItem(icon: "network", text: status.net)
                }.frame(maxWidth: .infinity, maxHeight: .infinity).padding([.horizontal], 11)
                }
            }
            .onChange(of: refreshAllCounter) { _ in
                if let url = url {
                    getStatus(url: url)
                }
            }
        }
    }
    
    func getStatus(url: String) {
        state = .loading
        if url.count < 12 {
            state = .error(.url("url len < 12"))
            return
        }
        guard let url = URL(string: url) else {
            state = .error(.url("parse url failed"))
            return
        }
        let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
            // 所有 UI 状态更新必须在主线程执行，否则可能导致 TabView 跳回第一页等问题
            func setStateOnMain(_ newState: ContentState) {
                DispatchQueue.main.async {
                    self.state = newState
                }
            }

            if let error = error {
                setStateOnMain(.error(.http(error.localizedDescription)))
                return
            }
            guard let data = data else {
                setStateOnMain(.error(.http("empty data")))
                return
            }
            guard let jsonAll = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                setStateOnMain(.error(.http("json parse fail")))
                return
            }
            guard let code = jsonAll["code"] as? Int else {
                setStateOnMain(.error(.http("code is nil")))
                return
            }
            if (code != 0) {
                let msg = jsonAll["msg"] as? String ?? ""
                setStateOnMain(.error(.http(msg)))
                return
            }

            let json = jsonAll["data"] as? [String: Any] ?? [:]
            let name = json["name"] as? String ?? ""
            let disk = json["disk"] as? String ?? ""
            let cpu = json["cpu"] as? String ?? ""
            let mem = json["mem"] as? String ?? ""
            let net = json["net"] as? String ?? ""
            let status = Status(name: name, cpu: cpu, mem: mem, disk: disk, net: net)
            setStateOnMain(.normal(status))
            // 将最新数据写入 App Group，供表盘/叠放的 Widget 使用
            let appGroupId = "group.com.lollipopkit.toolbox"
            if let defaults = UserDefaults(suiteName: appGroupId) {
                var statusMap = (defaults.dictionary(forKey: "watch_shared_status_by_url") as? [String: [String: String]]) ?? [:]
                statusMap[url.absoluteString] = [
                    "name": status.name,
                    "cpu": status.cpu,
                    "mem": status.mem,
                    "disk": status.disk,
                    "net": status.net
                ]
                defaults.set(statusMap, forKey: "watch_shared_status_by_url")
            }
        }
        task.resume()
    }
    
    // 监听“刷新全部”触发器变化，主动刷新当前页
    @ViewBuilder
    var _onRefreshAllHook: some View {
        EmptyView()
            .onChange(of: refreshAllCounter) { _ in
                if let url = url {
                    getStatus(url: url)
                }
            }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

struct DetailItem: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 5.7) {
            Image(systemName: icon).resizable().foregroundColor(.white).frame(width: 11, height: 11, alignment: .center)
            Text(text)
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.white)
        }
    }
}
