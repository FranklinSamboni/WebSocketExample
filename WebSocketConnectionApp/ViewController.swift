//
//  ViewController.swift
//  WebSocketConnectionApp
//
//

import UIKit
import Network


final class ViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    @IBOutlet weak var stateLabel: UILabel!
    @IBOutlet weak var input: UITextField!
    @IBOutlet weak var tableView: UITableView!
    
    var connection: WebSocketConnection!
    var messages: [MessageViewModel] = []
    
    struct MessageViewModel {
        let text: String
        let color: UIColor
        
        static func sent(_ text: String) -> MessageViewModel {
            MessageViewModel(text: text, color: UIColor.green)
        }
        static func received(_ text: String) -> MessageViewModel {
            MessageViewModel(text: text, color: UIColor.red)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        stateLabel.text = ""
        input.text = ""
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.keyboardDismissMode = .onDrag
        
        let socketURL = URL(string: "wss://echo.websocket.org")!
        connection = NWWebSocketConnection(webSocketURL: socketURL)
        connection.delegate = self
        connection.connect()
        

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    @IBAction func connect(_ sender: Any) {
        connection.connect()
    }
    
    @IBAction func disconenct(_ sender: Any) {
        connection.disconnect()
    }

    @IBAction func sendText() {
        connection.send(input.text ?? "")
        messages.append(.sent(input.text ?? ""))
        tableView.reloadData()
        input.text = ""
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.numberOfLines = 0
        cell.textLabel?.text = messages[indexPath.row].text
        cell.textLabel?.textColor = messages[indexPath.row].color
        return cell
    }
    
    var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    
    @objc func appDidEnterBackground() {
        connection.disconnect()
        
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
    }
    
    func endBackgroundTask() {
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }
    
    @objc func appDidBecomeActive() {
        if connection.status != .connected && connection.status != .connecting  {
            connection.connect()
        }
    }
}

extension ViewController: WebSocketConnectionDelegate {
    
    func webSocketStateDidChange(_ status: WebSocketConnectionState) {
        DispatchQueue.main.async {
            self.stateLabel.text = String(describing: status)
        }
    }
    
    func webSocketDidReceiveMessage(_ message: String) {
        DispatchQueue.main.async {
            self.messages.append(.received(message))
            self.tableView.reloadData()
        }
    }
    
    func webSocketDidReceiveMessage(_ data: Data) {
        
    }
    
    func webSocketDidReceiveError(_ error: Error) {
        DispatchQueue.main.async {
            self.messages.append(.received(error.localizedDescription))
            self.tableView.reloadData()
        }
    }
}
