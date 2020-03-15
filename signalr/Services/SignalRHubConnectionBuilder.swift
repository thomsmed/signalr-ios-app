//
//  SignalRHubService.swift
//  signalr
//
//  Created by thomsmed on 15/03/2020.
//  Copyright © 2020 Thomas A. Smedmann. All rights reserved.
//

import Foundation

class SignalRHubConnectionBuilder: SignalRHubConnectionBuilderProtocol {

    // TODO: Bruke dedikert DispatchQueue
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

private enum HubConnectionState {
    case created
    case started
    case stopped
}

class SignalRHubConnection: NSObject, SignalRHubConnectionProtocol {
    
    // MARK: Constants
    let delimiter = "\u{1E}";
    
    private var state: HubConnectionState = .created
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    
    // MARK: Properties
    var delegate: SignalRHubConnectionDelegate?
    var session: URLSession?
    var webSocketTask: URLSessionWebSocketTask?
    
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
        print("Got message")
    }
    
    func onUserJoinedGroup(_ completionHandler: @escaping (ChatGroup) -> Void) {
        if state != .started { return }
        print("Joined group")
    }
    
    func onUserLeftGroup(_ completionHandler: @escaping (ChatGroup) -> Void) {
        if state != .started { return }
        print("Left group")
    }
    
    func onUserConnected(_ completionHandler: @escaping (ChatUser) -> Void) {
        if state != .started { return }
        print("User connected")
    }
    
    func onUserDisconnected(_ completionHandler: @escaping (ChatUser) -> Void) {
        if state != .started { return }
        print("User disconnected")
    }
    
    func invokeSendMessage(_ completionHandler: (() -> Void)?) {
        if state != .started { return }
        
    }
    
    func invokeJoinGroup(_ completionHandler: (() -> Void)?) {
        if state != .started { return }
        
    }
    
    func invokeLeaveGroup(_ completionHandler: (() -> Void)?) {
        if state != .started { return }
        
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
                    print("This bad...")
                }
                self.receive()
            }
        }
    }
    
    private func handleDataString(_ dataString: String) {
        guard let data = dataString.data(using: .utf8), let message = try? decoder.decode(SignalRMessage.self, from: data) else {
            return
        }
        
        guard let type = message.type else {
            delegate?.signalRHubConnectionConnectionSuccess(self)
            return
        }
        
        if type == .ping {
            let pingMessage = "{\"type\":\(SignalRMessageType.ping)}" + delimiter
            webSocketTask?.send(URLSessionWebSocketTask.Message.string(pingMessage), completionHandler: onWebSocketSendComplete)
        }
        
        handleMessage(message, forType: type)
    }
    
    private func handleMessage(_ message: SignalRMessage, forType type: SignalRMessageType){
        if type == .completion {
            
        } else if type == .invocation {
        
        }
    }
    
    private func onWebSocketSendComplete(error: Error?) {
        if let error = error {
            print(error.localizedDescription)
            self.state = .stopped
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
        let handshakeMessage = "{\"protocol\":\"json\",\"version\":1}" + delimiter
        webSocketTask!.send(URLSessionWebSocketTask.Message.string(handshakeMessage), completionHandler: onWebSocketSendComplete)
    }
}
