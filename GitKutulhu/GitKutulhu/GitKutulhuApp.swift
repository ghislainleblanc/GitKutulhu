//
//  GitKutulhuApp.swift
//  GitKutulhu
//
//  Created by Ghislain Leblanc on 2026-10-11.
//

import AppKit
import SwiftUI

@main
struct GitKutulhuApp: App {
    @NSApplicationDelegateAdaptor(GitKutulhuAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 1380, height: 860)
        .windowStyle(.hiddenTitleBar)
    }
}

final class GitKutulhuAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_: Notification) {
        guard let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
              let icon = NSImage(contentsOf: iconURL)
        else { return }

        // Load the bundled artwork directly to refresh stale Dock icons during development.
        NSApplication.shared.applicationIconImage = icon
    }
}
