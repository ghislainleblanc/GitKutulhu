import SwiftUI

struct ContentView: View {
    @Bindable var repositories: RepositoryWorkspaceStore

    var body: some View {
        VStack(spacing: 0) {
            RepositoryTabBar(store: repositories)

            Divider()

            if let session = repositories.selectedRepository {
                RepositoryWorkspaceView(session: session)
                    .id(session.id)
            } else {
                ContentUnavailableView("No repositories open", systemImage: "folder", description: Text("Open a local repository or clone one to get started."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Palette.background)
        .foregroundStyle(Palette.text)
        .tint(Palette.accent)
        .preferredColorScheme(.dark)
        .frame(minWidth: 1080, minHeight: 700)
        .task { await repositories.restore() }
        .alert("Could not open repository", isPresented: Binding(get: { repositories.error != nil }, set: {
            if !$0 {
                repositories.error = nil
            }
        })) {
            Button("OK", role: .cancel) { repositories.error = nil }
        } message: {
            Text(verbatim: repositories.error ?? "")
        }
    }
}

struct RepositoryWorkspaceView: View {
    @Bindable var session: RepositorySession
    @State private var workspace = DemoWorkspace()
    @State private var showsBranchSheet = false
    @State private var branchName = ""

    var branches: BranchStore {
        session.branches
    }

    var body: some View {
        VStack(spacing: 0) {
            WorkspaceToolbar(store: branches, createBranch: { showsBranchSheet = true })

            Divider()

            HStack(spacing: 0) {
                RepositorySidebar(store: branches, section: $session.section, createBranch: { showsBranchSheet = true })
                    .frame(width: 218)

                Divider()

                VStack(spacing: 0) {
                    WorkspaceHeader(section: $session.section, search: $session.search)

                    Divider()

                    if branches.repository == nil {
                        RepositoryUnavailableView(session: session)
                    } else {
                        RepositorySectionView(session: session, workspace: $workspace)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Divider()

            WorkspaceStatusBar(store: branches)
        }
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
        .alert("Git operation failed", isPresented: Binding(get: { branches.repository != nil && branches.error != nil && !showsBranchSheet }, set: {
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

struct RepositorySectionView: View {
    let session: RepositorySession
    @Binding var workspace: DemoWorkspace

    var body: some View {
        switch session.section {
        case .history:
            HistoryView(repository: session.branches.repository, revision: session.branches.revision, search: session.search)

        case .changes:
            ChangesView(branches: session.branches, store: session.changes, search: session.search)

        case .conflicts:
            VStack(spacing: 0) {
                Text("Conflict resolution is a sample preview. No repository is modified here.")
                    .font(.caption).foregroundStyle(Palette.muted).padding(10)

                ConflictView(workspace: $workspace)
            }
        }
    }
}

struct RepositoryUnavailableView: View {
    let session: RepositorySession

    var body: some View {
        VStack(spacing: 16) {
            ContentUnavailableView("Repository unavailable", systemImage: "folder.badge.questionmark", description: Text("Reconnect the drive or restore the folder, then retry."))

            Text(verbatim: session.root.path).font(.caption).foregroundStyle(Palette.muted).textSelection(.enabled)

            if session.branches.isBusy {
                ProgressView()
            } else {
                if let error = session.branches.error {
                    Text(verbatim: error).font(.caption).foregroundStyle(.red).textSelection(.enabled)
                }

                Button("Retry") {
                    Task { await session.branches.load(at: session.root) }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ContentView(repositories: RepositoryWorkspaceStore())
}
