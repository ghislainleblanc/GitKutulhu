//
//  GitKutulhuApp.swift
//  GitKutulhu
//
//  Created by Ghislain Leblanc on 2026-10-11.
//

import SwiftUI

@main
struct GitKutulhuApp: App {
    @State private var repositories = RepositoryWorkspaceStore()

    var body: some Scene {
        WindowGroup {
            ContentView(repositories: repositories)
        }
        .defaultSize(width: 1380, height: 860)
        .windowStyle(.hiddenTitleBar)
    }
}
