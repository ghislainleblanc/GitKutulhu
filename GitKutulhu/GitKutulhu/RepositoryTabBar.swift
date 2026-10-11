import SwiftUI

struct RepositoryTabBar: View {
    let store: RepositoryWorkspaceStore
    @State private var showsCloneSheet = false

    var body: some View {
        HStack(spacing: 12) {
            Button(action: store.openRepository) {
                Label("Open repository", systemImage: "folder.badge.plus")
            }
            .disabled(store.isBusy)
            .keyboardShortcut("o", modifiers: .command)

            Button {
                store.cloneError = nil
                showsCloneSheet = true
            } label: {
                Label("Clone Repository", systemImage: "square.and.arrow.down")
            }
            .disabled(store.isBusy)

            if store.isOpening {
                ProgressView().controlSize(.small)
            }

            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    HStack(spacing: 6) {
                        ForEach(store.repositories) { repository in
                            RepositoryTab(store: store, repository: repository)
                                .id(repository.id)
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .accessibilityLabel("Open repositories")
                .onChange(of: store.selectedID, initial: true) { _, selection in
                    if let selection {
                        proxy.scrollTo(selection)
                    }
                }
            }
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 20).padding(.vertical, 10)
        .background(Palette.panel)
        .sheet(isPresented: $showsCloneSheet) {
            CloneRepositorySheet(store: store)
        }
    }
}

struct RepositoryTab: View {
    let store: RepositoryWorkspaceStore
    let repository: RepositorySession
    @State private var confirmsClose = false

    var isSelected: Bool {
        store.selectedID == repository.id
    }

    var body: some View {
        HStack(spacing: 8) {
            Button { store.select(repository) } label: {
                Label {
                    Text(verbatim: repository.root.lastPathComponent).lineLimit(1)
                } icon: {
                    Image(systemName: "folder")
                }
                .padding(.leading, 10).padding(.vertical, 8)
            }
            .accessibilityAddTraits(isSelected ? .isSelected : [])

            Button {
                if repository.changes.message.isEmpty {
                    store.close(repository)
                } else {
                    confirmsClose = true
                }
            } label: {
                Image(systemName: "xmark").font(.caption2).padding(8)
            }
            .disabled(repository.branches.isBusy)
            .help("Close repository")
            .accessibilityLabel(Text("Close repository \(repository.root.lastPathComponent)"))
        }
        .foregroundStyle(isSelected ? Palette.accent : Palette.muted)
        .background(isSelected ? Palette.accent.opacity(0.12) : Palette.background, in: RoundedRectangle(cornerRadius: 7))
        .help(Text(verbatim: repository.root.path))
        .confirmationDialog("Close repository?", isPresented: $confirmsClose, titleVisibility: .visible) {
            Button("Close repository", role: .destructive) { store.close(repository) }
        } message: {
            Text("The uncommitted message draft will be discarded. Files and staged changes are preserved.")
        }
    }
}
