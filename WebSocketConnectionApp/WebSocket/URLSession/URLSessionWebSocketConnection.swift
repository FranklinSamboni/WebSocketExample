//
//  URLSessionWebSocketConnection.swift
//  WebSocketConnectionApp
//
//

import Foundation
import Network

final class URLSessionWebSocketConnection: NSObject, WebSocketConnection {
    private let webSocketURI: URLRequest
    
    private let operationQueue = OperationQueue()
    private var webSocketTask: URLSessionWebSocketTask?
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        /*if #available(iOS 17.0, *) {
            let socksv5Proxy = NWEndpoint.hostPort(host: "192.168.1.4", port: 8889) // Proxyman socksv5Proxy port
            let proxyConfig = ProxyConfiguration.init(socksv5Proxy: socksv5Proxy)

            config.proxyConfigurations = [proxyConfig]
        }*/

        return URLSession(configuration: config, delegate: self, delegateQueue: operationQueue)
    }()

    weak var delegate: WebSocketConnectionDelegate?
    var status: WebSocketConnectionState = .disconnected
    
    init(webSocketURI: URLRequest) {
        self.webSocketURI = webSocketURI
    }

    func connect() {
        status = .connecting
        delegate?.webSocketStateDidChange(.connecting)
        
        webSocketTask = urlSession.webSocketTask(with: webSocketURI)
        webSocketTask?.resume()
    }

    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)

        status = .disconnected
        delegate?.webSocketStateDidChange(.disconnected)
    }
    
    func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let data):
                let msg: String =  switch data {
                case .data(let data):
                    String(data: data, encoding: .utf8) ?? ""
                case .string(let string):
                    string
                @unknown default:
                    ""
                }

                self.delegate?.webSocketDidReceiveMessage(msg)
                self.receiveMessage()
            case .failure(let error):
                self.delegate?.webSocketDidReceiveError(error)
                self.disconnect()
            }
        }
    }
    
    func send(_ message: String) {
        webSocketTask?.send(URLSessionWebSocketTask.Message.string(message), completionHandler: { error in
            if let error {
                self.delegate?.webSocketDidReceiveError(error)
            }
        })
    }
    
    func send(_ data: Data) {
        webSocketTask?.send(URLSessionWebSocketTask.Message.data(data), completionHandler: { error in
            if let error {
                self.delegate?.webSocketDidReceiveError(error)
            }
        })
    }
}

extension URLSessionWebSocketConnection: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        status = .connected
        receiveMessage()
        delegate?.webSocketStateDidChange(.connected)
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        status = .disconnected
        delegate?.webSocketStateDidChange(.disconnected)
    }
}
