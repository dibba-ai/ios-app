//
//  iosApp.swift
//  ios
//
//  Created by Klim on 10/11/25.
//

import Analytics
import os.log
import SwiftUI
import UIKit

private let logger = Logger(subsystem: "ai.dibba.ios", category: "iosApp")

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
    func application(
        _: UIApplication,
        didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        configurePostHog()
        return true
    }

    private func configurePostHog() {
        let token = (Bundle.main.object(forInfoDictionaryKey: "PostHogProjectToken") as? String) ?? ""
        let host = (Bundle.main.object(forInfoDictionaryKey: "PostHogHost") as? String) ?? ""
        guard !token.isEmpty, !host.isEmpty else {
            logger.warning("PostHogProjectToken or PostHogHost missing in Info.plist — analytics disabled")
            return
        }
        PostHogAnalytics.setup(projectToken: token, host: host)
    }
}
