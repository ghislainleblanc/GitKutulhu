import SwiftUI

struct ContentView: View {
    @State private var branches = BranchStore()
    @State private var workspace = DemoWorkspace()
    @State private var changes = ChangesStore()
    @State private var section: WorkspaceSection = .history
    @State private var search = ""
    @State private var showsBranchSheet = false
    @State private var branchName = ""

    var body: some View {
        VStack(spacing: 0) {
            WorkspaceToolbar(store: branches, createBranch: { showsBranchSheet = true })

            Divider()

            HStack(spacing: 0) {
                RepositorySidebar(store: branches, section: $section, createBranch: { showsBranchSheet = true })
                    .frame(width: 218)

                Divider()

                VStack(spacing: 0) {
                    WorkspaceHeader(section: $section, search: $search)

                    Divider()

                    switch section {
                    case .history:
                        HistoryView(repository: branches.repository, revision: branches.revision, search: search)
                    case .changes:
                        ChangesView(branches: branches, store: changes, search: search)
                    case .conflicts:
                        VStack(spacing: 0) {
                            Text("Conflict resolution is a sample preview. No repository is modified here.")
                                .font(.caption).foregroundStyle(Palette.muted).padding(10)

                            ConflictView(workspace: $workspace)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Divider()

            WorkspaceStatusBar(store: branches)
        }
        .background(Palette.background)
        .foregroundStyle(Palette.text)
        .tint(Palette.accent)
        .preferredColorScheme(.dark)
        .frame(minWidth: 1080, minHeight: 700)
        .sheet(isPresented: $showsBranchSheet) {
            BranchSheet(name: $branchName, isBusy: branches.isBusy, error: branches.error) {
                Task {
                    if await branches.create(branchName.trimmingCharacters(in: .whitespacesAndNewlines)) {
                        branchName = ""
                        showsBranchSheet = false
                    }
                }
            }
        }
        .alert("Git operation failed", isPresented: Binding(get: { branches.error != nil && !showsBranchSheet }, set: {
            if !$0 {
                branches.error = nil
            }
        })) {
            Button("OK", role: .cancel) { branches.error = nil }
        } message: {
            Text(verbatim: branches.error ?? "")
        }
        .onChange(of: showsBranchSheet) { _, shown in
            if !shown {
                branchName = ""
            }
        }
    }
}

#Preview {
    ContentView()
}
