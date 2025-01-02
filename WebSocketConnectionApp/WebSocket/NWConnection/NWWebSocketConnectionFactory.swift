//
//  NWWebSocketConnectionFactory.swift
//

import Foundation
import Network

final class NWWebSocketConnectionFactory {
    private let webSocketURL: URL
    
    init(webSocketURL: URL) {
        self.webSocketURL = webSocketURL
    }
    
    func options() -> NWProtocolWebSocket.Options {
        let options = NWProtocolWebSocket.Options()
        options.autoReplyPing = true
        
        return options
    }
    
    func parameters() -> NWParameters {
        let parameters = if webSocketURL.scheme == "wss" {
            NWParameters.tls
        } else {
            NWParameters.tcp
        }

        /*if #available(iOS 17.0, *) {
            let socksv5Proxy = NWEndpoint.hostPort(host: "192.168.1.6", port: 8889)
            let config = ProxyConfiguration.init(socksv5Proxy: socksv5Proxy)
            let context = NWParameters.PrivacyContext(description: "my socksv5Proxy")
            context.proxyConfigurations = [config]

            parameters.setPrivacyContext(context)
        }*/
        
        parameters.defaultProtocolStack.applicationProtocols.insert(options(), at: 0)
        return parameters
    }

    func make() -> NWConnection {
        return NWConnection(to: .url(webSocketURL), using: parameters())
    }
}
