//
//  NWWebSocketConnection.swift
//

import Foundation
import Network

final class NWWebSocketConnection: WebSocketConnection {
    deinit {
        connection?.cancel()
    }
    
    private let queue = DispatchQueue(label: "queue.NWWebSocketConnection")
    private let factory: NWWebSocketConnectionFactory
    private var connection: NWConnection?
    private var pingTimer: DispatchSourceTimer?
    private var reconnectionWorkItem: DispatchWorkItem?

    convenience init(webSocketURL: URL) {
        let factory = NWWebSocketConnectionFactory(webSocketURL: webSocketURL)
        self.init(factory: factory)
    }
    
    init(factory: NWWebSocketConnectionFactory) {
        self.factory = factory
    }

    weak var delegate: WebSocketConnectionDelegate?
    var status: WebSocketConnectionState {
        guard let connection else { return .disconnected }
        
        switch connection.state {
        case .setup:
            return .disconnected
        case .waiting(_):
            return .disconnected
        case .preparing:
            return .connecting
        case .ready:
            return .connected
        case .failed(_):
            return .disconnected
        case .cancelled:
            return .disconnected
        @unknown default:
            return .disconnected
        }
    }
    
    func connect() {
        guard connection == nil else { return }
    
        connection = factory.make()
        
        connection?.stateUpdateHandler = { [weak self] state in
            self?.stateUpdateHandler(state: state)
        }
        connection?.betterPathUpdateHandler = { [weak self] newHasBetterPath in
            self?.betterPathUpdateHandler(newHasBetterPath: newHasBetterPath)
        }
        connection?.viabilityUpdateHandler = { [weak self] isViable in
            self?.viabilityUpdateHandler(isViable: isViable)
        }
    
        receiveMessage()
        connection?.start(queue: queue)
    }

    func disconnect() {
        connection?.cancel()
    }
    
    func send(_ message: String) {
        guard let data = message.data(using: .utf8) else { return }
        let metadata = NWProtocolWebSocket.Metadata(opcode: .text)
        let context = NWConnection.ContentContext(identifier: "textContext",
                                                  metadata: [metadata])

        send(data: data, context: context)
    }

    func send(_ data: Data) {
        let metadata = NWProtocolWebSocket.Metadata(opcode: .binary)
        let context = NWConnection.ContentContext(identifier: "binaryContext",
                                                  metadata: [metadata])

        send(data: data, context: context)
    }

    // MARK: Private helper methods

    private func stateUpdateHandler(state: NWConnection.State) {
        switch state {
        case .setup:
            delegate?.webSocketStateDidChange(.connecting)
        case .preparing:
            delegate?.webSocketStateDidChange(.connecting)
        case .ready:
            delegate?.webSocketStateDidChange(.connected)
            heartbeat()
        case .waiting(let error):
            delegate?.webSocketDidReceiveError(error)
        case .failed(let error):
            delegate?.webSocketDidReceiveError(error)
            closeConnection()
        case .cancelled:
            closeConnection()
        @unknown default:
            break
        }
    }
    
    private func closeConnection() {
        pingTimer?.cancel()
        connection?.cancel()
        connection = nil

        delegate?.webSocketStateDidChange(.disconnected)
        
        // If re-connection has been scheduled, execute it now that current connection has been fully closed
        if let reconnectionWorkItem = reconnectionWorkItem {
            queue.async(execute: reconnectionWorkItem)
            //reconnectionWorkItem.cancel()
        }
    }

    private func betterPathUpdateHandler(newHasBetterPath: Bool) {
        if newHasBetterPath {
            connection?.cancel()

            scheduleReconnection()
        }
    }

    private func viabilityUpdateHandler(isViable: Bool) {
        if !isViable {
            connection?.cancel()

            scheduleReconnection()
        }
    }
    
    private func scheduleReconnection() {
        // Schedule creation of a new connection once current connection is fully cancelled
        // in order to try a reconnection to a viable or better path
        reconnectionWorkItem?.cancel()
        reconnectionWorkItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.connect()
            
            self.reconnectionWorkItem?.cancel()
            self.reconnectionWorkItem = nil
        }
    }

    private func heartbeat() {
        pingTimer = DispatchSource.makeTimerSource(queue: queue)
        pingTimer?.setEventHandler { [weak self] in
            guard let self = self else { return }
            self.ping()
        }
        pingTimer?.schedule(deadline: .now(), repeating: .seconds(30))
        pingTimer?.resume()
    }

    private func ping() {
        let metadata = NWProtocolWebSocket.Metadata(opcode: .ping)
        metadata.setPongHandler(queue) { [weak self] error in
            guard let self = self else {
                return
            }

            if let error = error {
                self.delegate?.webSocketDidReceiveError(error)
            }
        }
        
        let context = NWConnection.ContentContext(identifier: "pingContext",
                                                  metadata: [metadata])
        send(data: "ping".data(using: .utf8), context: context)
    }

    private func receiveMessage() {
        connection?.receiveMessage { [weak self] (data, context, _, error) in
            guard let self = self else { return }

            if let data, let context {
                self.handleReceivedMessage(data: data, context: context)
            }

            if let error {
                self.delegate?.webSocketDidReceiveError(error)
            } else {
                self.receiveMessage()
            }
        }
    }

    private func handleReceivedMessage(data: Data, context: NWConnection.ContentContext) {
        guard !data.isEmpty,
              let metadata = context.protocolMetadata.first as? NWProtocolWebSocket.Metadata else {
            return
        }

        switch metadata.opcode {
        case .binary:
            delegate?.webSocketDidReceiveMessage(data)
        case .text:
            guard let string = String(data: data, encoding: .utf8) else { return }
            delegate?.webSocketDidReceiveMessage(string)
        case .close:
            delegate?.webSocketStateDidChange(.disconnected)
        case .cont:
            break
        case .ping:
            break // be sure `autoReplyPing = true` so no need to respond here
        case .pong:
            break
        @unknown default: 
            break
        }
    }

    private func send(data: Data?, context: NWConnection.ContentContext) {
        guard let connection = connection else {
            delegate?.webSocketDidReceiveError(NWError.posix(.ENOTCONN))
            return
        }
        
        if case let .waiting(error) = connection.state {
            delegate?.webSocketDidReceiveError(error)
        } else {
            connection.send(
                content: data,
                contentContext: context,
                isComplete: true,
                completion: .contentProcessed({ [weak self] error in
                    guard let self = self else { return }

                    if let error = error {
                        self.delegate?.webSocketDidReceiveError(error)
                    }
                })
            )
        }
    }
}
