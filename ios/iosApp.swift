//
//  iosApp.swift
//  ios
//
//  Created by Klim on 10/11/25.
//

import Analytics
import Dependencies
import SwiftUI
import UIKit

@main
struct iosApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    @Dependency(\.analytics) private var analytics

    func application(
        _: UIApplication,
        didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        Analytics.bootstrap()
        analytics.capture(.appOpened)
        return true
    }
}
