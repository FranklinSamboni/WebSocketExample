//
//  WebSocketConnection.swift
//

import Foundation

enum WebSocketConnectionState {
    case disconnected
    case connecting
    case connected
}

protocol WebSocketConnection: AnyObject {
    var delegate: WebSocketConnectionDelegate? { get set }
    var status: WebSocketConnectionState { get }

    func connect()
    func disconnect()
    func send(_ message: String)
    func send(_ data: Data)
}

// Methods can be call in any thread, clients are resposible to dispatch work to the correct thread.
protocol WebSocketConnectionDelegate: AnyObject {
    func webSocketStateDidChange(_ status: WebSocketConnectionState)
    func webSocketDidReceiveMessage(_ message: String)
    func webSocketDidReceiveMessage(_ data: Data)
    func webSocketDidReceiveError(_ error: Error)
}
