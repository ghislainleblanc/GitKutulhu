import SwiftUI

enum WorkspaceSection: String, CaseIterable, Identifiable {
    case history, changes

    var id: Self {
        self
    }

    var title: LocalizedStringKey {
        switch self {
        case .history: "History"
        case .changes: "Changes"
        }
    }
}
