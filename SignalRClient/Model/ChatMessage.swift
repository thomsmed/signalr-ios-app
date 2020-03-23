//
//  ChatGroup.swift
//  signalr
//
//  Created by thomsmed on 15/03/2020.
//  Copyright © 2020 Thomas A. Smedmann. All rights reserved.
//

import Foundation

struct ChatMessage: Codable {
    var id = ""
    var sender = ""
    var reciever = ""
    var group = ""
    var header = ""
    var body = ""
}

struct ChatGroup: Codable {
    var id = ""
    var name = ""
    var participant = ""
}

struct ChatUser: Codable {
    var id = ""
    var name = ""
}
