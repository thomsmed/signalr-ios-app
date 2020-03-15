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
        
        let message = ChatMessage(id: UUID().uuidString, sender: "Myself", reciever: "Myself", group: "Global", header: "", body: "Hi there!")
        chatMessages.append(message)
        
    }
    
    @IBAction func togglePrivateGroup(_ sender: UIButton) {
        if let title = sender.currentTitle, title == "Join Private" {
            sender.setTitle("Leave Private", for: .normal)
        } else {
            sender.setTitle("Join Private", for: .normal)
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
        print("Connection success!")
    }
}
