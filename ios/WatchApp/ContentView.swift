//
//  ContentView.swift
//  WatchEnd Watch App
//
//  Created by lolli on 2023/9/16.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var _mgr = PhoneConnMgr()
    
    var body: some View {
        let _count = _mgr.urls.count == 0 ? 1 : _mgr.urls.count
        TabView {
            ForEach(0 ..< _count, id:\.self) { index in
                let url = _count == 1 && _mgr.urls.count == 0 ? nil : _mgr.urls[index]
                PageView(url: url, state: .loading)
            }
        }
        .tabViewStyle(PageTabViewStyle())
    }
}

struct PageView: View {
    let url: String?
    @State var state: ContentState
    
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
                        Button(action: {
                            state = .loading
                        }){
                            Image(systemName: "arrow.clockwise")
                        }.buttonStyle(.plain)
                    }
                case .url(_):
                    Link("View help", destination: helpUrl)
                }
            case .normal(let status):
                VStack(alignment: .leading) {
                    HStack {
                        Text(status.name).font(.system(.title, design: .monospaced))
                        Spacer()
                        Button(action: {
                            state = .loading
                        }){
                            Image(systemName: "arrow.clockwise")
                        }.buttonStyle(.plain)
                    }
                    Spacer()
                    DetailItem(icon: "cpu", text: status.cpu)
                    DetailItem(icon: "memorychip", text: status.mem)
                    DetailItem(icon: "externaldrive", text: status.disk)
                    DetailItem(icon: "network", text: status.net)
                }.frame(maxWidth: .infinity, maxHeight: .infinity).padding([.horizontal], 11)
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
            guard error == nil else {
                state = .error(.http(error!.localizedDescription))
                return
            }
            guard let data = data else {
                state = .error(.http("empty data"))
                return
            }
            guard let jsonAll = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                state = .error(.http("json parse fail"))
                return
            }
            guard let code = jsonAll["code"] as? Int else {
                state = .error(.http("code is nil"))
                return
            }
            if (code != 0) {
                let msg = jsonAll["msg"] as? String ?? ""
                state = .error(.http(msg))
                return
            }

            let json = jsonAll["data"] as? [String: Any] ?? [:]
            let name = json["name"] as? String ?? ""
            let disk = json["disk"] as? String ?? ""
            let cpu = json["cpu"] as? String ?? ""
            let mem = json["mem"] as? String ?? ""
            let net = json["net"] as? String ?? ""
            state = .normal(Status(name: name, cpu: cpu, mem: mem, disk: disk, net: net))
        }
        task.resume()
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
