//
//  ChatViewController.swift
//  signalr
//
//  Created by thomsmed on 14/03/2020.
//  Copyright © 2020 Thomas A. Smedmann. All rights reserved.
//

import Foundation
import UIKit
import Resolver

class ChatViewController: UIViewController {
    
    // MARK: Constants
    let nicknameUrl = URL(string: "http://0.0.0.0:5000/nickname")!
    let chatWsUrl = URL(string: "ws://0.0.0.0:5000/chat")!
    
    // MARK: Services
    @Injected var signalRHubConnectionBuilder: SignalRHubConnectionBuilderProtocol
    
    // MARK: Properties
    var signalRChatHubConnection: SignalRHubConnectionProtocol?
    
    var chatGroups = [ChatGroup]()
    var chatMessages = [ChatMessage]()
    
    // MARK: Outlets
    @IBOutlet weak var groupLabel: UITextField!
    @IBOutlet weak var togglePrivateButton: UIButton!
    @IBOutlet weak var tableView: UITableView! {
        didSet {
            tableView.layer.borderColor = UIColor.lightGray.cgColor
            tableView.layer.borderWidth = 1
            tableView.layer.cornerRadius = 5
        }
    }
    @IBOutlet weak var textView: UITextView! {
        didSet {
            textView.layer.borderColor = UIColor.lightGray.cgColor
            textView.layer.borderWidth = 2
            textView.layer.cornerRadius = 5
        }
    }
    @IBOutlet weak var sendButton: UIButton!
    
    // MARK: Actions
    @IBAction func sendMessage(_ sender: UIButton) {
        // Get selected group id
        // construct message
        // send
        
        let message = ChatMessage(id: UUID().uuidString, sender: "", reciever: "", group: "", header: "", body: "Hi there!")
        
        signalRChatHubConnection?.invokeSendMessage(message, nil)
    }
    
    @IBAction func togglePrivateGroup(_ sender: UIButton) {
        if let title = sender.currentTitle, title == "Join Private" {
            sender.setTitle("Leave Private", for: .normal)
            signalRChatHubConnection?.invokeJoinGroup(ChatGroup(id: "private"), { _ in
                self.chatMessages.append(ChatMessage(body: "You joined group private!"))
                self.tableView.insertRows(at: [IndexPath(row: self.chatMessages.count - 1, section: 0)], with: .bottom)
                self.chatGroups.append(ChatGroup(id: "private"))
            })
        } else {
            sender.setTitle("Join Private", for: .normal)
            signalRChatHubConnection?.invokeLeaveGroup(ChatGroup(id: "private"), { _ in
                self.chatMessages.append(ChatMessage(body: "You left group private..."))
                self.tableView.insertRows(at: [IndexPath(row: self.chatMessages.count - 1, section: 0)], with: .bottom)
                self.chatGroups.removeAll(where: { chatGroup in chatGroup.id == "private" })
            })
        }
    }
    
    // MARK: Overrides
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        let groupPicker = UIPickerView()
        groupPicker.delegate = self
        groupPicker.dataSource = self
        groupLabel.inputView = groupPicker
        
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        signalRChatHubConnection = signalRHubConnectionBuilder
            .withUrl(chatWsUrl)
            .build()
        signalRChatHubConnection!.delegate = self
        signalRChatHubConnection!.start()
        setupListeners()
    }
    
    private func setupListeners() {
        signalRChatHubConnection?.onReceiveMessage({ chatMessage in
            self.chatMessages.append(chatMessage)
            self.tableView.insertRows(at: [IndexPath(row: self.chatMessages.count - 1, section: 0)], with: .bottom)
        })
        signalRChatHubConnection?.onUserJoinedGroup({ group in
            self.chatMessages.append(ChatMessage(body: "UserJoinedGroup \(group.id) (\(group.participant))"))
            self.tableView.insertRows(at: [IndexPath(row: self.chatMessages.count - 1, section: 0)], with: .bottom)
        })
        signalRChatHubConnection?.onUserLeftGroup({ group in
            self.chatMessages.append(ChatMessage(body: "UserLeftGroup \(group.id) (\(group.participant))"))
            self.tableView.insertRows(at: [IndexPath(row: self.chatMessages.count - 1, section: 0)], with: .bottom)
        })
        signalRChatHubConnection?.onUserConnected({ chatUser in
            self.chatMessages.append(ChatMessage(body: "UserConnected (\(chatUser.id))"))
            self.tableView.insertRows(at: [IndexPath(row: self.chatMessages.count - 1, section: 0)], with: .bottom)
        })
        signalRChatHubConnection?.onUserDisconnected({ chatUser in
            self.chatMessages.append(ChatMessage(body: "UserDisconnected (\(chatUser.id))"))
            self.tableView.insertRows(at: [IndexPath(row: self.chatMessages.count - 1, section: 0)], with: .bottom)
        })
    }
}

extension ChatViewController: UIPickerViewDelegate {
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return chatGroups[row].id
    }
}

extension ChatViewController: UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return chatGroups.count
    }
}

extension ChatViewController: UITableViewDelegate {
    
}

extension ChatViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return chatMessages.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell()
        let message = chatMessages[indexPath.row]
        cell.textLabel?.text = message.body
        return cell
    }
}

extension ChatViewController: UITableViewDataSourcePrefetching {
    func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        
    }
}

extension ChatViewController: SignalRHubConnectionDelegate {
    func signalRHubConnectionConnectionSuccess(_ signalRHubConnection: SignalRHubConnection) {
        self.chatMessages.append(ChatMessage(body: "Connection success!"))
        self.tableView.insertRows(at: [IndexPath(row: self.chatMessages.count - 1, section: 0)], with: .bottom)
        self.signalRChatHubConnection?.invokeJoinGroup(ChatGroup(id: "global"), { _ in
            self.chatMessages.append(ChatMessage(body: "You joined group global!"))
            self.tableView.insertRows(at: [IndexPath(row: self.chatMessages.count - 1, section: 0)], with: .bottom)
            self.chatGroups.append(ChatGroup(id: "global"))
        })
    }
}
