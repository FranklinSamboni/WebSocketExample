//
//  SceneDelegate.swift
//  WebSocketConnectionApp
//
//

import UIKit
import Atlantis

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let scene = (scene as? UIWindowScene) else { return }
        window = UIWindow(windowScene: scene)
        
        let st = UIStoryboard(name: "WebSocket", bundle: nil)
        let vc = st.instantiateInitialViewController()
        window?.rootViewController = vc
        window?.makeKeyAndVisible()
    }
}

