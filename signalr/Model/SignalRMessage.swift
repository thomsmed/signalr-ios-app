//
//  SignalRMessage.swift
//  signalr
//
//  Created by thomsmed on 15/03/2020.
//  Copyright © 2020 Thomas A. Smedmann. All rights reserved.
//

import Foundation

enum SignalRMessageType: Int, Codable {
    case invocation = 1
    case streamItem = 2
    case completion = 3
    case streamInvocation = 4
    case cancelInvocation = 5
    case ping = 6
    case close = 7
}

struct SignalRMessage: Codable {
    var type: SignalRMessageType?
    var target: String?
    var invocationId: String?
    var error: String?
    var result: String?
    var arguments: [String]?
}
