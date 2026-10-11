import SwiftUI

enum WorkspaceSection: String, CaseIterable, Identifiable {
    case history, changes, conflicts

    var id: Self {
        self
    }

    var title: LocalizedStringKey {
        switch self {
        case .history: "History"
        case .changes: "Changes"
        case .conflicts: "Conflicts"
        }
    }
}

struct DemoWorkspace {
    var resolved = false
    var resolution = ""
}
