import UIKit
import WidgetKit
import Flutter
import ActivityKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // No scene is connected yet at this point, and the scene delegate is
        // `FlutterSceneDelegate` (see UIApplicationSceneManifest), so there is
        // no subclass of ours to hook. Observing is what gets a UIWindowScene to
        // work with. Both fire again on every foreground, and both calls are
        // idempotent.
        NotificationCenter.default.addObserver(
            forName: UIScene.didActivateNotification,
            object: nil,
            queue: .main
        ) { note in
            guard let scene = note.object as? UIWindowScene else { return }
            DynamicIslandBrand.shared.install(in: scene)
            PrivacyBlur.shared.hideIfUnlocked()
        }

        // `willDeactivate` and not `didEnterBackground`: the switcher snapshot
        // is taken between the two, and by the latter it is already on file.
        // The cost is that a pulled-down notification centre or a system alert
        // also blurs for as long as it is up.
        NotificationCenter.default.addObserver(
            forName: UIScene.willDeactivateNotification,
            object: nil,
            queue: .main
        ) { note in
            guard let scene = note.object as? UIWindowScene else { return }
            PrivacyBlur.shared.show(in: scene)
        }

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
        setupMethodChannels(binaryMessenger: engineBridge.applicationRegistrar.messenger())
    }

    private func setupMethodChannels(binaryMessenger: FlutterBinaryMessenger) {
        let homeWidgetChannel = FlutterMethodChannel(name: "tech.lolli.toolbox/home_widget", binaryMessenger: binaryMessenger)
        homeWidgetChannel.setMethodCallHandler({(call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            switch call.method {
            case "update":
                if #available(iOS 14.0, *) {
                    // Every kind: there are two home widgets now, and which
                    // one is placed is not knowable from here.
                    WidgetCenter.shared.reloadAllTimelines()
                }
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        })

        let mainChannel = FlutterMethodChannel(name: "tech.lolli.toolbox/main_chan", binaryMessenger: binaryMessenger)
        mainChannel.setMethodCallHandler({(call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            switch call.method {
            case "updateHomeWidget":
                if #available(iOS 14.0, *) {
                    // Every kind: there are two home widgets now, and which
                    // one is placed is not knowable from here.
                    WidgetCenter.shared.reloadAllTimelines()
                }
                result(nil)
            // The three Live Activity cases answer from inside the Task, not
            // after starting it. ActivityKit is what takes the time here, and
            // none of it may run on this thread; replying only once it is done
            // is also what keeps the Dart side's queue ordering these calls.
            case "startLiveActivity":
                if #available(iOS 16.2, *), let payload = call.arguments as? String {
                    Task {
                        await LiveActivityManager.shared.start(json: payload)
                        result(nil)
                    }
                } else {
                    result(nil)
                }
            case "updateLiveActivity":
                if #available(iOS 16.2, *), let payload = call.arguments as? String {
                    Task {
                        await LiveActivityManager.shared.update(json: payload)
                        result(nil)
                    }
                } else {
                    result(nil)
                }
            case "stopLiveActivity":
                if #available(iOS 16.2, *) {
                    Task {
                        await LiveActivityManager.shared.stop()
                        result(nil)
                    }
                } else {
                    result(nil)
                }
            case "setIslandBrandColors":
                if let args = call.arguments as? [String: Any],
                   let bg = args["bg"] as? Int,
                   let fg = args["fg"] as? Int {
                    DynamicIslandBrand.shared.setColors(background: bg, foreground: fg)
                }
                result(nil)
            case "setPrivacyBlur":
                PrivacyBlur.shared.isEnabled = call.arguments as? Bool ?? false
                result(nil)
            case "setPrivacyBlurLocked":
                PrivacyBlur.shared.setLocked(call.arguments as? Bool ?? false)
                result(nil)
            case "publishWidgetServers":
                guard let payload = call.arguments as? String else {
                    result(nil)
                    return
                }
                Self.publishWidgetServers(payload)
                result(nil)
            case "widgetTokenState":
                result(Self.widgetTokenState())
            default:
                result(FlutterMethodNotImplemented)
            }
        })
    }

    /// Splits `WidgetSync`'s payload between the two containers: the list into
    /// the App Group, every token into the shared Keychain.
    ///
    /// A server whose entry carries no `token` keeps whatever is already
    /// stored for it. The app publishes the full list on every change, and an
    /// agent that happened to be unreachable when it did so must not cost the
    /// widget the credential it was working with — the entry's `expiresAt` is
    /// zero in that case, so nothing here claims it has one either.
    private static func publishWidgetServers(_ payload: String) {
        guard let data = payload.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let raw = root["servers"] as? [[String: Any]]
        else { return }

        var servers: [WidgetServer] = []
        for entry in raw {
            guard let id = entry["id"] as? String, !id.isEmpty,
                  let addr = entry["addr"] as? String, !addr.isEmpty
            else { continue }

            let stored = WidgetStore.server(id: id)
            // Only while the entry still names the endpoint the stored
            // credential was minted against. A token is scoped to one agent,
            // so after an address change the held one is not a credential the
            // widget can fall back on — it is a request that will be refused,
            // and an `expiresAt` inherited alongside it would report a working
            // credential and stop anything asking for a real one.
            let sameEndpoint = stored?.addr == addr
            if let token = entry["token"] as? String, !token.isEmpty {
                WidgetStore.setToken(token, for: id)
            } else if !sameEndpoint {
                WidgetStore.setToken(nil, for: id)
            }
            let expiresAt = (entry["expiresAt"] as? NSNumber)?.intValue ?? 0
            servers.append(
                WidgetServer(
                    id: id,
                    name: entry["name"] as? String ?? addr,
                    addr: addr,
                    ignoreCert: entry["ignoreCert"] as? Bool ?? false,
                    allowInsecure: entry["allowInsecure"] as? Bool ?? false,
                    // Kept from the stored entry when this push brought no
                    // token, so a transient failure does not read as "the
                    // credential is gone".
                    tokenExpiresAt: expiresAt > 0
                        ? expiresAt
                        : (sameEndpoint ? stored?.tokenExpiresAt ?? 0 : 0)
                )
            )
        }

        WidgetStore.setServers(servers)
        if #available(iOS 14.0, *) {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// What is actually held, as JSON — never the tokens themselves.
    ///
    /// The Keychain is consulted per server rather than trusting the stored
    /// `tokenExpiresAt`, because the two can disagree: a restore brings back
    /// one container without the other, and a renewal decision made from a
    /// deadline whose credential no longer exists would skip the server
    /// forever.
    private static func widgetTokenState() -> String {
        let held = WidgetStore.servers().compactMap { server -> [String: Any]? in
            guard WidgetStore.token(for: server.id) != nil else { return nil }
            return [
                "id": server.id,
                "endpoint": server.addr,
                "expiresAt": server.tokenExpiresAt,
            ]
        }
        guard let data = try? JSONSerialization.data(withJSONObject: held),
              let json = String(data: data, encoding: .utf8)
        else { return "[]" }
        return json
    }

    override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        if url.scheme == "https" || url.scheme == "http" {
            UIApplication.shared.open(url)
        } else {
            // Pass
        }
        return true
    }

    override func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // UIScene apps use this callback when the user closes the app from the
        // app switcher. applicationWillTerminate is not reliable for that path.
        //
        // Deliberately no `super`. This is an optional UIApplicationDelegate
        // method and FlutterAppDelegate does not implement it, so forwarding
        // raises NSInvalidArgumentException and terminates the app. Checked
        // with `otool -oV Flutter`: the selector is in the protocol's name
        // table with no imp behind it.
        if #available(iOS 16.2, *) {
            Task { await LiveActivityManager.shared.stop() }
        }
    }

    override func applicationWillTerminate(_ application: UIApplication) {
        // Stop Live Activity when app is about to terminate
        if #available(iOS 16.2, *) {
            Task { await LiveActivityManager.shared.stop() }
        }
        // This one FlutterAppDelegate does implement, and it is how registered
        // plugins hear that the app is going away.
        super.applicationWillTerminate(application)
    }
}
