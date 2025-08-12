//
//  TerminalLiveActivityAttributes.swift
//  StatusWidget
//
//  Defines ActivityKit attributes and content state for SSH/Terminal Live Activities.
//

import Foundation
import ActivityKit

@available(iOS 16.1, *)
public struct TerminalAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var id: String
        public var title: String
        public var subtitle: String
        public var status: String
        public var startTime: Date
        public var hasTerminal: Bool
        public var connectionCount: Int

        public init(id: String, title: String, subtitle: String, status: String, startTime: Date, hasTerminal: Bool, connectionCount: Int = 1) {
            self.id = id
            self.title = title
            self.subtitle = subtitle
            self.status = status
            self.startTime = startTime
            self.hasTerminal = hasTerminal
            self.connectionCount = connectionCount
        }
    }

    public var id: String

    public init(id: String) {
        self.id = id
    }
}

