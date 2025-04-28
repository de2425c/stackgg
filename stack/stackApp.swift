//
//  stackApp.swift
//  stack
//
//  Created by David Eyal on 4/25/25.
//

import SwiftUI
import FirebaseCore
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        return true
    }
}

@main
struct stackApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject var userService = UserService()

    var body: some Scene {
        WindowGroup {
            MainCoordinator()
                .environmentObject(authViewModel)
                .environmentObject(userService)
        }
    }
}
