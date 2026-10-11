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
    var staged: Set<String> = []
    var selectedFile = DemoFile.samples[0].id
    var message = ""
    var committed = false
    var resolved = false
    var resolution = ""
}

struct DemoFile: Identifiable {
    let id: String
    let folder: String
    let additions: Int
    let deletions: Int
    let old: [String]
    let new: [String]

    static let samples = [
        DemoFile(id: "CommitGraph.swift", folder: "Sources / Views", additions: 12, deletions: 4,
                 old: ["struct CommitGraph: View {", "    var body: some View {", "        VStack {", "            Text(\"History\")", "        }", "    }", "}"],
                 new: ["struct CommitGraph: View {", "    let commits: [Commit]", "", "    var body: some View {", "        ScrollView {", "            LazyVStack(spacing: 0) {", "                ForEach(commits) { commit in", "                    CommitRow(commit: commit)", "                }", "            }", "        }", "    }", "}"]),
        DemoFile(id: "BranchLabel.swift", folder: "Sources / Components", additions: 8, deletions: 2,
                 old: ["struct BranchLabel: View {", "    let name: String", "    var body: some View {", "        Text(name)", "    }", "}"],
                 new: ["struct BranchLabel: View {", "    let name: String", "    var body: some View {", "        Label(name, systemImage: \"arrow.triangle.branch\")", "            .font(.caption)", "            .padding(6)", "    }", "}"]),
        DemoFile(id: "GraphLayout.swift", folder: "Sources / Models", additions: 24, deletions: 0,
                 old: [], new: ["struct GraphLayout {", "    let laneWidth: CGFloat = 24", "    let rowHeight: CGFloat = 48", "", "    func position(lane: Int, row: Int) -> CGPoint {", "        CGPoint(x: CGFloat(lane) * laneWidth,", "                y: CGFloat(row) * rowHeight)", "    }", "}"]),
    ]
}
