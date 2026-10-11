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

struct DemoCommit: Identifiable {
    let id: String
    let title: LocalizedStringResource
    let author: String
    let branch: String?
    let lane: Int
    let age: Int

    static let samples: [DemoCommit] = [
        .init(id: "f8a21c4", title: "Add commit graph and branch lanes", author: "You", branch: "feature/graph-view", lane: 0, age: 12),
        .init(id: "c3d9e82", title: "Refine sidebar spacing and selection", author: "Alex Morgan", branch: "fix/sidebar-layout", lane: 2, age: 38),
        .init(id: "a42b7d1", title: "Build repository workspace layout", author: "You", branch: nil, lane: 0, age: 65),
        .init(id: "91e6f03", title: "Merge branch feature/diff-viewer", author: "Sam Chen", branch: "develop", lane: 1, age: 120),
        .init(id: "7bc890a", title: "Add syntax highlighting to diffs", author: "Sam Chen", branch: nil, lane: 2, age: 180),
        .init(id: "62d14fe", title: "Support side-by-side file comparison", author: "Sam Chen", branch: nil, lane: 2, age: 240),
        .init(id: "4e8b2c0", title: "Set up app theme and typography", author: "You", branch: "main", lane: 1, age: 360),
        .init(id: "20a7f91", title: "Create the initial workspace", author: "You", branch: nil, lane: 1, age: 480),
    ]
}
