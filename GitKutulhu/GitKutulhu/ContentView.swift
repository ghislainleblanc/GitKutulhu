import SwiftUI

struct ContentView: View {
    @State private var workspace = DemoWorkspace()
    @State private var section: WorkspaceSection = .history
    @State private var search = ""
    @State private var showsBranchSheet = false
    @State private var branchName = ""
    @State private var notice: String?

    var body: some View {
        VStack(spacing: 0) {
            WorkspaceToolbar(branch: workspace.branch, createBranch: { showsBranchSheet = true }, action: showDemoNotice)
            Divider()
            HStack(spacing: 0) {
                RepositorySidebar(workspace: $workspace, section: $section, createBranch: { showsBranchSheet = true })
                    .frame(width: 218)
                Divider()
                VStack(spacing: 0) {
                    WorkspaceHeader(section: $section, search: $search)
                    Divider()
                    switch section {
                    case .history:
                        HistoryView(search: search)
                    case .changes:
                        ChangesView(workspace: $workspace, search: search)
                    case .conflicts:
                        ConflictView(workspace: $workspace)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Divider()
            WorkspaceStatusBar(branch: workspace.branch)
        }
        .background(Palette.background)
        .foregroundStyle(Palette.text)
        .tint(Palette.accent)
        .preferredColorScheme(.dark)
        .frame(minWidth: 1080, minHeight: 700)
        .sheet(isPresented: $showsBranchSheet) {
            BranchSheet(name: $branchName) {
                let name = branchName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return }
                if !workspace.branches.contains(name) {
                    workspace.branches.append(name)
                }
                workspace.branch = name
                branchName = ""
                showsBranchSheet = false
            }
        }
        .alert("Demo workspace", isPresented: Binding(get: { notice != nil }, set: {
            if !$0 {
                notice = nil
            }
        })) {
            Button("OK", role: .cancel) { notice = nil }
        } message: {
            Text(notice ?? "")
        }
    }
}

private extension ContentView {
    func showDemoNotice() {
        notice = String(localized: "This is a UI preview. Connect a repository to enable Git operations.")
    }
}

#Preview {
    ContentView()
}
