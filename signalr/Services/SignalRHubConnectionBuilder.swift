//
//  SignalRHubService.swift
//  signalr
//
//  Created by thomsmed on 15/03/2020.
//  Copyright © 2020 Thomas A. Smedmann. All rights reserved.
//

import Foundation

class SignalRHubConnectionBuilder: SignalRHubConnectionBuilderProtocol {

    // TODO: Use a dedicated DispatchQueue and or OperationQueue
    var dispatchQueue: DispatchQueue = DispatchQueue.main
    
    var url: URL?
    
    func withUrl(_ url: URL) -> SignalRHubConnectionBuilder {
        self.url = url
        return self
    }
    
    func build() -> SignalRHubConnection {
        return SignalRHubConnection(withUrl: self.url!)
    }
}

class SignalRHubConnection: NSObject, SignalRHubConnectionProtocol {
    private enum HubConnectionState {
        case created
        case started
        case stopped
    }
    
    // MARK: Constants
    let delimiter: Character = "\u{1E}";
    
    private var state: HubConnectionState = .created
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    
    // MARK: Properties
    var delegate: SignalRHubConnectionDelegate?
    var session: URLSession?
    var webSocketTask: URLSessionWebSocketTask?
    
    var messageEventListeners = [String: (ChatMessage) -> Void]()
    var groupEventListeners = [String: (ChatGroup) -> Void]()
    var userEventListeners = [String: (ChatUser) -> Void]()
    var invocationCallbacks = [String: (Error?) -> Void]()
    
    required init(withUrl url: URL) {
        super.init()
        let sessionConfiguration = URLSessionConfiguration.default
        session = URLSession(configuration: sessionConfiguration, delegate: self, delegateQueue: OperationQueue.main)
        webSocketTask = session!.webSocketTask(with: url)
    }
    
    // MARK: Overrides
    func start() {
        if state != .created { return }
        state = .started
        webSocketTask!.resume()
    }
    
    func onReceiveMessage(_ completionHandler: @escaping (ChatMessage) -> Void) {
        if state != .started { return }
        messageEventListeners["RecieveMessage"] = completionHandler
    }
    
    func onUserJoinedGroup(_ completionHandler: @escaping (ChatGroup) -> Void) {
        if state != .started { return }
        groupEventListeners["UserJoinedGroup"] = completionHandler
    }
    
    func onUserLeftGroup(_ completionHandler: @escaping (ChatGroup) -> Void) {
        if state != .started { return }
        groupEventListeners["UserLeftGroup"] = completionHandler
    }
    
    func onUserConnected(_ completionHandler: @escaping (ChatUser) -> Void) {
        if state != .started { return }
        userEventListeners["UserConnected"] = completionHandler
    }
    
    func onUserDisconnected(_ completionHandler: @escaping (ChatUser) -> Void) {
        if state != .started { return }
        userEventListeners["UserDisconnected"] = completionHandler
    }
    
    func invokeSendMessage(_ message: ChatMessage, _ completionHandler: ((Error?) -> Void)?) {
        if state != .started { return }
        let key = "\(invocationCallbacks.count)"
        let target = message.reciever != "" ? "SendMessageToUser" : message.group != "" ? "SendMessageToGroup" : "SendMessageToCaller"
        let argument: [String: String?] = ["reciever": message.reciever, "group": message.group, "body": message.body]
        let message = SignalRMessage(type: .invocation, target: target, invocationId: key, error: nil, result: nil, arguments: [argument])
        
        invocationCallbacks[key] = completionHandler
        
        guard let messageData = try? encoder.encode(message),
            var messageString = String(data: messageData, encoding: .utf8) else {
            return
        }
        
        messageString.append(delimiter)
        
        webSocketTask?.send(URLSessionWebSocketTask.Message.string(messageString), completionHandler: onWebSocketSendComplete)
    }
    
    func invokeJoinGroup(_ group: ChatGroup, _ completionHandler: ((Error?) -> Void)?) {
        if state != .started { return }
        let key = "\(invocationCallbacks.count)"
        let target = "JoinGroup"
        let argument: [String: String?] = ["id": group.id]
        let message = SignalRMessage(type: .invocation, target: target, invocationId: key, error: nil, result: nil, arguments: [argument])
        
        invocationCallbacks[key] = completionHandler
        
        guard let messageData = try? encoder.encode(message),
            var messageString = String(data: messageData, encoding: .utf8) else {
            return
        }
        
        messageString.append(delimiter)
        
        webSocketTask?.send(URLSessionWebSocketTask.Message.string(messageString), completionHandler: onWebSocketSendComplete)
    }
    
    func invokeLeaveGroup(_ group: ChatGroup, _ completionHandler: ((Error?) -> Void)?) {
        if state != .started { return }
        let key = "\(invocationCallbacks.count)"
        let target = "LeavGroup"
        let argument: [String: String?] = ["id": group.id]
        let message = SignalRMessage(type: .invocation, target: target, invocationId: key, error: nil, result: nil, arguments: [argument])
        
        invocationCallbacks[key] = completionHandler
        
        guard let messageData = try? encoder.encode(message),
            var messageString = String(data: messageData, encoding: .utf8) else {
            return
        }
        
        messageString.append(delimiter)
        
        webSocketTask?.send(URLSessionWebSocketTask.Message.string(messageString), completionHandler: onWebSocketSendComplete)
    }
    
    // MARK: Private Methods
    private func receive() {
        webSocketTask?.receive { result in
            switch result {
            case .failure(let error):
                print(error.localizedDescription)
            case .success(let message):
                switch message {
                case .data(let data):
                    print("Got data from socket: \(data)")
                case .string(let dataString):
                    self.handleDataString(dataString)
                @unknown default:
                    print("This is bad...")
                }
                self.receive()
            }
        }
    }
    
    private func handleDataString(_ dataString: String) {
        let dataStringMessages = dataString.split(separator: delimiter)
        for dataStringMessage in dataStringMessages {
            guard let data = dataStringMessage.data(using: .utf8), let message = try? decoder.decode(SignalRMessage.self, from: data) else {
                return
            }
            
            guard let type = message.type else {
                delegate?.signalRHubConnectionConnectionSuccess(self)
                return
            }
            
            if type == .ping {
                var pingMessage = String(dataStringMessage)
                pingMessage.append(delimiter)
                webSocketTask?.send(URLSessionWebSocketTask.Message.string(pingMessage), completionHandler: onWebSocketSendComplete)
            } else if type == .close {
                state = .stopped
                webSocketTask?.cancel()
            } else {
                handleMessage(message, forType: type)
            }
        }
    }
    
    private func handleMessage(_ message: SignalRMessage, forType type: SignalRMessageType){
        if type == .completion {
            handleCompletionMessage(message)
        } else if type == .invocation {
            handleInvocationMessage(message)
        }
    }
    
    private func handleCompletionMessage(_ message: SignalRMessage) {
        guard let invocationId = message.invocationId else {
            return
        }
        
        guard let callback = invocationCallbacks[invocationId] else {
            return
        }
        
        if let errorMessage = message.error {
            callback(SignalRHubConnectionInvocationError.error(message: errorMessage))
        } else {
            callback(nil)
        }
        
        invocationCallbacks.removeValue(forKey: invocationId)
    }
    
    private func handleInvocationMessage(_ message: SignalRMessage) {
        guard let target = message.target else {
            return
        }
        
        guard let arguments = message.arguments, arguments.count > 0 else {
            return
        }
        
        let argumentDictionary = arguments[0]
        if target.contains("Message") {
            let chatMessage = ChatMessage(id: (argumentDictionary["id"] ?? "") ?? "",
                                          sender: (argumentDictionary["sender"] ?? "") ?? "",
                                          reciever: (argumentDictionary["reciever"] ?? "") ?? "",
                                          group: (argumentDictionary["group"] ?? "") ?? "",
                                          header: (argumentDictionary["header"] ?? "") ?? "",
                                          body: (argumentDictionary["body"] ?? "") ?? "")
            
            if let listener = messageEventListeners["RecieveMessage"] {
                listener(chatMessage)
            }
        } else if target.contains("Group") {
            let chatGroup = ChatGroup(id: (argumentDictionary["id"] ?? "") ?? "", name: (argumentDictionary["name"] ?? "") ?? "", participant: (argumentDictionary["participant"] ?? "") ?? "")
            
            if let listener = groupEventListeners[target] {
                listener(chatGroup)
            }
        } else if target.contains("onnected") {
            let chatUser = ChatUser(id: (argumentDictionary["id"] ?? "") ?? "", name: (argumentDictionary["name"] ?? "") ?? "")
            
            if let listener = userEventListeners[target] {
                listener(chatUser)
            }
        }
    }
    
    private func onWebSocketSendComplete(error: Error?) {
        if let error = error {
            print(error.localizedDescription)
        } else {
            // Success
        }
    }
}

extension SignalRHubConnection: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol wsProtocol: String?) {
        if let prot = wsProtocol {
            print("Protocol: \(prot)")
        }
        
        receive()
        startHandshake()
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        state = .stopped
    }
    
    private func startHandshake() {
        var handshakeMessage = "{\"protocol\":\"json\",\"version\":1}"
        handshakeMessage.append(delimiter)
        webSocketTask?.send(URLSessionWebSocketTask.Message.string(handshakeMessage), completionHandler: onWebSocketSendComplete)
    }
}
