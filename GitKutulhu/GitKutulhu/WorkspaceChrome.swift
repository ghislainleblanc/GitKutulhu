import SwiftUI

struct WorkspaceToolbar: View {
    @Bindable var store: BranchStore
    let createBranch: () -> Void

    var body: some View {
        HStack(spacing: 18) {
            Label { Text(verbatim: "GitKutulhu") } icon: {
                Image(systemName: "point.3.connected.trianglepath.dotted")
            }.font(.headline).foregroundStyle(Palette.accent)

            Text(verbatim: store.repository?.root.lastPathComponent ?? "").lineLimit(1)

            Label { Text(verbatim: store.branchLabel) } icon: { Image(systemName: "arrow.triangle.branch") }
                .foregroundStyle(Palette.accent).lineLimit(1)

            Spacer()

            if store.isBusy {
                ProgressView().controlSize(.small)
            }

            Button(action: store.refresh) { Label("Refresh", systemImage: "arrow.clockwise") }
                .disabled(store.repository == nil)

            Button(action: store.fetch) { Label("Fetch", systemImage: "arrow.down.circle") }
                .help("Fetch remote changes").disabled(store.repository?.remotes.isEmpty != false)

            Picker("Remote", selection: $store.selectedRemote) {
                if store.selectedRemote.isEmpty {
                    Text("No remote").tag("")
                }

                ForEach(store.repository?.remotes ?? [], id: \.self) { Text(verbatim: $0).tag($0) }
            }.frame(maxWidth: 140)

            Button(action: store.push) { Label("Push branch", systemImage: "arrow.up") }
                .help("Publish the current branch to the selected remote")
                .disabled(store.repository?.currentBranch == nil || store.selectedRemote.isEmpty)

            Button(action: createBranch) { Label("Branch", systemImage: "arrow.triangle.branch") }
                .disabled(store.repository == nil)
        }
        .disabled(store.isBusy)
        .buttonStyle(.borderless)
        .padding(.horizontal, 20).frame(height: 58)
        .background(Palette.panel)
    }
}

struct RepositorySidebar: View {
    let store: BranchStore
    @Binding var section: WorkspaceSection
    let createBranch: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("WORKSPACE").font(.caption2.weight(.semibold)).foregroundStyle(Palette.muted)

                    Text(verbatim: store.repository?.root.lastPathComponent ?? String(localized: "No repository"))
                        .font(.title3.weight(.semibold))

                    if let root = store.repository?.root {
                        Text(verbatim: root.path).font(.caption).foregroundStyle(Palette.muted).textSelection(.enabled)
                    } else {
                        Text("Open a local clone to manage its GitHub branches.").font(.caption).foregroundStyle(Palette.muted)
                    }
                }

                VStack(spacing: 5) {
                    SidebarItem(title: "Commit history", icon: "clock.arrow.circlepath", selected: section == .history) { section = .history }

                    SidebarItem(title: "Working changes", icon: "square.and.pencil", selected: section == .changes) { section = .changes }

                    SidebarItem(title: "Merge conflicts", icon: "exclamationmark.triangle", selected: section == .conflicts) { section = .conflicts }
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("LOCAL BRANCHES").font(.caption2.weight(.semibold)).foregroundStyle(Palette.muted)

                        Spacer()

                        Button(action: createBranch) { Image(systemName: "plus") }
                            .buttonStyle(.plain).help("Create branch").accessibilityLabel("Create branch")
                            .disabled(store.repository == nil || store.isBusy)
                    }

                    ForEach(store.repository?.branches.filter { $0.remote == nil } ?? []) { branch in
                        RepositoryBranchRow(store: store, branch: branch)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("REMOTE BRANCHES").font(.caption2.weight(.semibold)).foregroundStyle(Palette.muted)

                    ForEach(store.repository?.branches.filter { $0.remote != nil } ?? []) { branch in
                        RepositoryBranchRow(store: store, branch: branch)
                    }

                    Text("Fetch to update remote branches.").font(.caption).foregroundStyle(Palette.muted)
                }
            }.padding(16)
        }.background(Palette.panel)
    }
}

struct RepositoryBranchRow: View {
    let store: BranchStore
    let branch: GitBranch
    @State private var showsRename = false
    @State private var showsDelete = false
    @State private var name = ""

    var isCurrent: Bool {
        branch.remote == nil && store.repository?.currentBranch == branch.name
    }

    var displayName: String {
        branch.remote.map { $0 + "/" + branch.name } ?? branch.name
    }

    var body: some View {
        Button { store.checkout(branch) } label: {
            HStack(spacing: 9) {
                Image(systemName: "arrow.triangle.branch")

                VStack(alignment: .leading, spacing: 3) {
                    Text(verbatim: displayName).lineLimit(1).truncationMode(.middle)

                    if !branch.upstream.isEmpty {
                        Text(verbatim: branch.upstream).font(.caption2).foregroundStyle(Palette.muted)
                    }
                }

                Spacer(minLength: 0)

                if isCurrent {
                    Image(systemName: "checkmark").font(.caption2)
                }
            }
            .font(.caption).foregroundStyle(isCurrent ? Palette.accent : Palette.muted)
            .padding(.vertical, 7).padding(.horizontal, 8)
            .background(isCurrent ? Palette.accent.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain).disabled(store.isBusy)
        .help("Check out branch")
        .contextMenu {
            Button("Check out branch") { store.checkout(branch) }.disabled(isCurrent || store.isBusy)

            if branch.remote == nil {
                Button("Rename branch") { name = branch.name; showsRename = true }.disabled(store.isBusy)

                Button("Delete local branch", role: .destructive) { showsDelete = true }.disabled(isCurrent || store.isBusy)
            }
        }
        .alert("Rename branch", isPresented: $showsRename) {
            TextField("Branch name", text: $name)

            Button("Cancel", role: .cancel) {}

            Button("Rename") { store.rename(branch, to: name) }.disabled(name.isEmpty)
        } message: {
            Text("Renaming affects the local branch only.")
        }
        .confirmationDialog("Delete local branch?", isPresented: $showsDelete, titleVisibility: .visible) {
            Button("Delete local branch", role: .destructive) { store.delete(branch) }
        } message: {
            Text(verbatim: branch.name)

            Text("The remote branch is preserved. Git will refuse to delete an unmerged branch.")
        }
    }
}

struct SidebarItem: View {
    let title: LocalizedStringKey
    let icon: String
    var count: Int?
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon).frame(width: 16)

                Text(title)

                Spacer(minLength: 2)

                if let count {
                    Text(count, format: .number).font(.caption2).padding(.horizontal, 6).padding(.vertical, 2).background(.white.opacity(0.07), in: Capsule())
                }
            }
            .font(.callout).padding(10)
            .foregroundStyle(selected ? Palette.accent : Palette.text)
            .background(selected ? Palette.accent.opacity(0.1) : .clear, in: RoundedRectangle(cornerRadius: 7))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct WorkspaceHeader: View {
    @Binding var section: WorkspaceSection
    @Binding var search: String

    var body: some View {
        HStack {
            Picker("Workspace view", selection: $section) {
                ForEach(WorkspaceSection.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented).labelsHidden().frame(width: 300)

            Spacer()

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(Palette.muted)

                TextField("Filter commits or files…", text: $search).textFieldStyle(.plain)
            }
            .padding(8).frame(width: 235).background(Palette.raised, in: RoundedRectangle(cornerRadius: 6))
        }
        .padding(.horizontal, 20).frame(height: 58)
    }
}

struct BranchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var name: String
    let isBusy: Bool
    let error: String?
    let create: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Create branch", systemImage: "arrow.triangle.branch").font(.title2.weight(.semibold))

            Text("Create and check out a local branch from the current HEAD. Push to publish it on GitHub.").foregroundStyle(Palette.muted)

            TextField("Branch name", text: $name).onSubmit {
                if isValid, !isBusy {
                    create()
                }
            }

            if let error {
                Text(verbatim: error).font(.caption).foregroundStyle(.red).textSelection(.enabled)
            }

            HStack {
                Spacer()

                Button("Cancel", role: .cancel) { dismiss() }.disabled(isBusy).keyboardShortcut(.cancelAction)

                Button("Create branch", action: create).buttonStyle(.borderedProminent).disabled(!isValid || isBusy).keyboardShortcut(.defaultAction)
            }
        }.padding(24).frame(width: 480).tint(Palette.accent)
            .interactiveDismissDisabled(isBusy)
    }

    private var isValid: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)

        return !trimmed.isEmpty && !trimmed.contains(where: \.isWhitespace) && !trimmed.contains("..")
    }
}

struct WorkspaceStatusBar: View {
    let store: BranchStore

    var body: some View {
        HStack(spacing: 14) {
            Circle().fill(Palette.accent).frame(width: 6, height: 6)

            Text(store.isBusy ? LocalizedStringKey("Running Git…") : LocalizedStringKey("Branch management")).foregroundStyle(Palette.muted)

            Divider().frame(height: 12)

            Label { Text(verbatim: store.branchLabel) } icon: { Image(systemName: "arrow.triangle.branch") }

            Spacer()

            Label("Local repository", systemImage: "internaldrive")

            Text(verbatim: "GitKutulhu 0.1").foregroundStyle(Palette.muted)
        }.font(.caption2).padding(.horizontal, 18).frame(height: 30).background(Palette.panel)
    }
}
