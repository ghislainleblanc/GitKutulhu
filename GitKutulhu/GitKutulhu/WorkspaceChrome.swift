import SwiftUI

struct WorkspaceToolbar: View {
    let branch: String
    let createBranch: () -> Void
    let action: () -> Void

    var body: some View {
        HStack(spacing: 22) {
            HStack(spacing: 10) {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.title2).foregroundStyle(Palette.accent)
                Text(verbatim: "GitKutulhu").font(.headline)
            }
            .frame(width: 194, alignment: .leading)
            Label { Text(verbatim: "GitKutulhu") } icon: { Image(systemName: "folder") }
                .font(.callout.weight(.medium))
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Palette.muted)
            Label { Text(verbatim: branch) } icon: { Image(systemName: "arrow.triangle.branch") }
                .foregroundStyle(Palette.accent).font(.callout)
            Spacer()
            Button(action: action) { Label("Fetch", systemImage: "arrow.down.circle") }
                .help("Fetch remote changes")
            Button(action: action) { Label("Pull", systemImage: "arrow.down") }
            Button(action: action) { Label("Push", systemImage: "arrow.up") }
            Divider().frame(height: 20)
            Button(action: createBranch) { Label("Branch", systemImage: "arrow.triangle.branch") }
            Menu {
                Button("Merge into current branch", action: action)
                Button("Rebase current branch", action: action)
            } label: {
                Label("Integrate", systemImage: "arrow.triangle.merge")
            }
            .menuStyle(.borderlessButton).fixedSize()
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 20).frame(height: 58)
        .background(Palette.panel)
    }
}

struct RepositorySidebar: View {
    @Binding var workspace: DemoWorkspace
    @Binding var section: WorkspaceSection
    let createBranch: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 5) {
                Text("WORKSPACE").font(.caption2.weight(.semibold)).foregroundStyle(Palette.muted)
                Text(verbatim: "GitKutulhu").font(.title3.weight(.semibold))
                Text("Local repository · Demo").font(.caption).foregroundStyle(Palette.muted)
            }
            VStack(spacing: 5) {
                SidebarItem(title: "Commit history", icon: "clock.arrow.circlepath", selected: section == .history) { section = .history }
                SidebarItem(title: "Working changes", icon: "square.and.pencil", count: workspace.committed ? 0 : 3, selected: section == .changes) { section = .changes }
                SidebarItem(title: "Merge conflicts", icon: "exclamationmark.triangle", count: workspace.resolved ? 0 : 1, selected: section == .conflicts) { section = .conflicts }
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("LOCAL BRANCHES").font(.caption2.weight(.semibold)).foregroundStyle(Palette.muted)
                    Spacer()
                    Button(action: createBranch) { Image(systemName: "plus") }
                        .buttonStyle(.plain).help("Create branch").accessibilityLabel("Create branch")
                }
                ForEach(workspace.branches, id: \.self) { branch in
                    Button { workspace.branch = branch } label: {
                        HStack(spacing: 9) {
                            Image(systemName: "arrow.triangle.branch")
                            Text(verbatim: branch).lineLimit(1).truncationMode(.middle)
                            Spacer(minLength: 0)
                            if workspace.branch == branch {
                                Image(systemName: "checkmark").font(.caption2)
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(workspace.branch == branch ? Palette.accent : Palette.muted)
                        .padding(.vertical, 7).padding(.horizontal, 8)
                        .background(workspace.branch == branch ? Palette.accent.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }
            VStack(alignment: .leading, spacing: 12) {
                Text("REMOTES").font(.caption2.weight(.semibold)).foregroundStyle(Palette.muted)
                Label { Text(verbatim: "origin") } icon: { Image(systemName: "network") }
                Text(verbatim: "origin/main").padding(.leading, 25)
                Text(verbatim: "origin/develop").padding(.leading, 25)
            }
            .font(.caption).foregroundStyle(Palette.muted)
            Spacer()
            VStack(alignment: .leading, spacing: 9) {
                Label("Your workflow, in focus.", systemImage: "sparkles").foregroundStyle(Palette.accent)
                Text("Review changes. Resolve conflicts. Keep moving.").foregroundStyle(Palette.muted)
            }
            .font(.caption).padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.raised, in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(16).background(Palette.panel)
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
    let create: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Create branch", systemImage: "arrow.triangle.branch").font(.title2.weight(.semibold))
            Text("Create and check out a branch in the demo workspace.").foregroundStyle(Palette.muted)
            TextField("Branch name", text: $name).onSubmit {
                if isValid {
                    create()
                }
            }
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Create branch", action: create).buttonStyle(.borderedProminent).disabled(!isValid).keyboardShortcut(.defaultAction)
            }
        }.padding(24).frame(width: 420).tint(Palette.accent)
    }

    private var isValid: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && !trimmed.contains(where: \.isWhitespace) && !trimmed.contains("..")
    }
}

struct WorkspaceStatusBar: View {
    let branch: String

    var body: some View {
        HStack(spacing: 14) {
            Circle().fill(Palette.accent).frame(width: 6, height: 6)
            Text("Demo workspace").foregroundStyle(Palette.muted)
            Divider().frame(height: 12)
            Label { Text(verbatim: branch) } icon: { Image(systemName: "arrow.triangle.branch") }
            Spacer()
            Label("Local preview", systemImage: "internaldrive")
            Text(verbatim: "GitKutulhu 0.1").foregroundStyle(Palette.muted)
        }.font(.caption2).padding(.horizontal, 18).frame(height: 30).background(Palette.panel)
    }
}
