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
        }
        get {
            return _ctx
        }
    }
    @Published var urls: [String] = []
    
    override init() {
        super.init()
        if !WCSession.isSupported() {
            print("WCSession not supported")
        }
        session = WCSession.default
        session?.delegate = self
        session?.activate()
        
        ctx = Store.getCtx()
    }
 
    func updateUrls(_ val: [String: Any]) {
        if let urls = val["urls"] as? [String] {
            self.urls = urls.filter { !$0.isEmpty }
        }
    }
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        
    }

    // implement session:didReceiveApplicationContext:
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        ctx = applicationContext
    }
}


