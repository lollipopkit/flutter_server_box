//
//  PhoneConnMgr.swift
//  WatchEnd Watch App
//
//  Created by lolli on 2023/9/16.
//

import WatchConnectivity

class PhoneConnMgr: NSObject, WCSessionDelegate, ObservableObject {
    var session: WCSession?
    var _ctx: [String: Any] = [:]
    var ctx: [String: Any] {
        set {
            Store.setCtx(newValue)
            updateUrls(newValue)

            // Notify the view to update, but the [urls] are already published
            // so the view will automatically update when [urls] changes.
            // DispatchQueue.main.async {
            //     self.objectWillChange.send()
            // }
        }
        get {
            return _ctx
        }
    }
    var userInfo: [String: Any] = [:]
    @Published var urls: [String] = []

    override init() {
        super.init()
        if !WCSession.isSupported() {
            print("WCSession not supported")
        }
        session = WCSession.default
        session?.delegate = self
        session?.activate()

        _ctx = Store.getCtx()
        updateUrls(_ctx)
    }

    func updateUrls(_ val: [String: Any]) {
        if let urls = val["urls"] as? [String] {
            DispatchQueue.main.async {
                self.urls = urls.filter { !$0.isEmpty }
            }
        }
    }

    func session(
        _ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        // Request latest data when the session is activated
        if activationState == .activated {
            requestLatestData()
        }
    }

    // Receive realtime msgs
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async {
            self.ctx = message
        }
    }

    // Receive UserInfo
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        DispatchQueue.main.async {
            self.ctx = userInfo
        }
    }

    // Receive Application Context
    func session(
        _ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        DispatchQueue.main.async {
            self.ctx = applicationContext
        }
    }

    private func requestLatestData() {
        guard let session = session, session.isReachable else { return }

        // Send a message to request the latest data
        session.sendMessage(["action": "requestData"]) { response in
            DispatchQueue.main.async {
                self.ctx = response
            }
        } errorHandler: { error in
            print("Request data failed: \(error)")
        }
    }
}
