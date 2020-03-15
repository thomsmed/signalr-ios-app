//
//  SignalRHubConnectionBuilderProtocol.swift
//  signalr
//
//  Created by thomsmed on 15/03/2020.
//  Copyright © 2020 Thomas A. Smedmann. All rights reserved.
//

import Foundation

enum SignalRHubFailure: Error {
    
}

enum SignalRHubConnectionInvocationMethod {
    case sendMessageToCaller
    case sendMessageToUser
    case sendMessageToGroup
    case joinGroup
    case leaveGroup
}

enum SignalRHubConnectionEventType {
    case receiveMessageFromSelf
    case receiveMessageFromUser
    case receiveMessageFromGroup
    case userJoinedGroup
    case userLeftGroup
    case userConnected
    case userDisconnected
}

protocol SignalRHubConnectionBuilderProtocol: AnyObject {
    func withUrl(_ url: URL) -> SignalRHubConnectionBuilder
    func build() -> SignalRHubConnection
}

protocol SignalRHubConnectionDelegate {
    func signalRHubConnectionConnectionSuccess(_ signalRHubConnection: SignalRHubConnection)
}

protocol SignalRHubConnectionProtocol: AnyObject {
    var delegate: SignalRHubConnectionDelegate? { get set }
    init(withUrl url: URL)
    func start()
    func onReceiveMessage(_ completionHandler: @escaping (_ message: ChatMessage) -> Void)
    func onUserJoinedGroup(_ completionHandler: @escaping (_ group: ChatGroup) -> Void)
    func onUserLeftGroup(_ completionHandler: @escaping (_ group: ChatGroup) -> Void)
    func onUserConnected(_ completionHandler: @escaping (_ group: ChatUser) -> Void)
    func onUserDisconnected(_ completionHandler: @escaping (_ group: ChatUser) -> Void)
    func invokeSendMessage(_ completionHandler: (() -> Void)?)
    func invokeJoinGroup(_ completionHandler: (() -> Void)?)
    func invokeLeaveGroup(_ completionHandler: (() -> Void)?)
}
