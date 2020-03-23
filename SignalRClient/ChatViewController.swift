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
    
    var chatGroups: [ChatGroup] = [ChatGroup(id: "", name: "Group: myself", participant: "")]
    var chatMessages = [ChatMessage]()
    
    var groupPicker = UIPickerView()
    
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
    @IBOutlet weak var textViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var sendButtonConstraint: NSLayoutConstraint!
    
    // MARK: Actions
    @IBAction func sendMessage(_ sender: UIButton) {
        guard let messageBody = textView.text, !messageBody.isEmpty else {
            return
        }
        
        let selectedGroupIndex = groupPicker.selectedRow(inComponent: 0)
        let selectedGroup = chatGroups[selectedGroupIndex]
        let message = ChatMessage(
            id: UUID().uuidString,
            sender: "",
            reciever: "",
            group:
            selectedGroup.id,
            header: "",
            body: messageBody)
        
        signalRChatHubConnection?.invokeSendMessage(message, nil)
        
        textView.text = ""
    }
    
    @IBAction func togglePrivateGroup(_ sender: UIButton) {
        if let title = sender.currentTitle, title == "Join Private" {
            sender.setTitle("Leave Private", for: .normal)
            signalRChatHubConnection?.invokeJoinGroup(ChatGroup(id: "private"), { _ in
                self.appendToChat(chatMessage: ChatMessage(body: "You joined group private!"))
                self.chatGroups.append(ChatGroup(id: "private", name: "Group: private"))
            })
        } else {
            sender.setTitle("Join Private", for: .normal)
            signalRChatHubConnection?.invokeLeaveGroup(ChatGroup(id: "private"), { _ in
                self.appendToChat(chatMessage: ChatMessage(body: "You left group private..."))
                
                guard let indexToRemove = self.chatGroups.firstIndex(where: { chatGroup in
                    return chatGroup.id == "private"
                }) else {
                    return
                }
                
                self.chatGroups.remove(at: indexToRemove)
                if self.groupPicker.selectedRow(inComponent: 0) == indexToRemove {
                    self.groupPicker.selectRow(0, inComponent: 0, animated: false)
                    self.groupLabel.text = self.chatGroups[0].name
                }
                self.groupPicker.reloadComponent(0)
            })
        }
    }
    
    // MARK: Overrides
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        groupPicker.delegate = self
        groupPicker.dataSource = self
        groupPicker.selectRow(0, inComponent: 0, animated: false)
        groupLabel.inputView = groupPicker
        groupLabel.text = chatGroups[0].name
        
        // Enable self-sizing table view cells
        tableView.estimatedRowHeight = 100.0
        tableView.rowHeight = UITableView.automaticDimension
        
        let tap = UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing))
        tap.cancelsTouchesInView = false
        tableView.addGestureRecognizer(tap)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        signalRChatHubConnection = signalRHubConnectionBuilder
            .withUrl(chatWsUrl)
            .build()
        signalRChatHubConnection!.delegate = self
        signalRChatHubConnection!.start()
        setupListeners()
        addObservers()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        signalRChatHubConnection?.stop()
        removeObservers()
    }
    
    // MARK: Private Methods
    private func addObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    private func removeObservers() {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    @objc
    private func keyboardWillShow(notification: NSNotification) {
        guard let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue.size else {
            return
        }
        self.textViewBottomConstraint.constant = keyboardSize.height
        self.sendButtonConstraint.constant = keyboardSize.height
        self.view.layoutIfNeeded()
    }
    
    @objc
    private func keyboardWillHide(notification: NSNotification) {
        self.textViewBottomConstraint.constant = 0
        self.sendButtonConstraint.constant = 0
        self.view.layoutIfNeeded()
    }
    
    private func setupListeners() {
        signalRChatHubConnection?.onReceiveMessage({ chatMessage in
            self.appendToChat(chatMessage: chatMessage)
        })
        signalRChatHubConnection?.onUserJoinedGroup({ group in
            self.appendToChat(chatMessage: ChatMessage(body: "UserJoinedGroup \(group.id) (\(group.participant))"))
        })
        signalRChatHubConnection?.onUserLeftGroup({ group in
            self.appendToChat(chatMessage: ChatMessage(body: "UserLeftGroup \(group.id) (\(group.participant))"))
        })
        signalRChatHubConnection?.onUserConnected({ chatUser in
            self.appendToChat(chatMessage: ChatMessage(body: "UserConnected (\(chatUser.id))"))
        })
        signalRChatHubConnection?.onUserDisconnected({ chatUser in
            self.appendToChat(chatMessage: ChatMessage(body: "UserDisconnected (\(chatUser.id))"))
        })
    }
    
    private func appendToChat(chatMessage: ChatMessage) {
        chatMessages.append(chatMessage)
        tableView.insertRows(at: [IndexPath(row: self.chatMessages.count - 1, section: 0)], with: .bottom)
        tableView.scrollToRow(at: IndexPath(row: chatMessages.count - 1, section: 0), at: .bottom, animated: true)
    }
}

// MARK: UIPickerViewDelegate
extension ChatViewController: UIPickerViewDelegate {
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return chatGroups[row].name
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        groupLabel.text = chatGroups[row].name
    }
}

// MARK: UIPickerViewDataSource
extension ChatViewController: UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return chatGroups.count
    }
}

// MARK: UITableViewDelegate
extension ChatViewController: UITableViewDelegate {
    
}

// MARK: UITableViewDataSource
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

// MARK: UITableViewDataSourcePrefetching
extension ChatViewController: UITableViewDataSourcePrefetching {
    func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        
    }
}

// MARK: SignalRHubConnectionDelegate
extension ChatViewController: SignalRHubConnectionDelegate {
    func signalRHubConnectionConnectionSuccess(_ signalRHubConnection: SignalRHubConnection) {
        appendToChat(chatMessage: ChatMessage(body: "Connection success!"))
        self.signalRChatHubConnection?.invokeJoinGroup(ChatGroup(id: "global"), { _ in
            self.appendToChat(chatMessage: ChatMessage(body: "You joined group global!"))
            self.chatGroups.append(ChatGroup(id: "global", name: "Group: global"))
        })
    }
}
