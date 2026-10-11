import AppKit
import Observation
import SwiftUI

@MainActor
@Observable
final class RepositorySession: Identifiable {
    nonisolated let root: URL
    let branches: BranchStore
    let changes = ChangesStore()
    var section: WorkspaceSection = .history
    var search = ""

    nonisolated var id: URL {
        root
    }

    init(root: URL, snapshot: GitRepositorySnapshot? = nil) {
        self.root = root
        branches = BranchStore(repository: snapshot)
    }
}

@MainActor
@Observable
final class RepositoryWorkspaceStore {
    private(set) var repositories: [RepositorySession] = []
    private(set) var selectedID: URL?
    private(set) var isOpening = false
    var error: String?
    private let defaults: UserDefaults
    private let service = GitBranchService()
    private var didRestore = false
    private static let persistenceKey = "repositoryWorkspace.v1"

    var selectedRepository: RepositorySession? {
        repositories.first { $0.id == selectedID }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        guard let data = defaults.data(forKey: Self.persistenceKey),
              let saved = try? JSONDecoder().decode(SavedWorkspace.self, from: data) else { return }

        for path in saved.paths {
            let root = URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL

            if !repositories.contains(where: { $0.root == root }) {
                repositories.append(RepositorySession(root: root))
            }
        }

        selectedID = repositories.first { $0.root.path == saved.selectedPath }?.id ?? repositories.first?.id
    }

    func restore() async {
        guard !didRestore else { return }

        didRestore = true

        for repository in repositories {
            await repository.branches.load(at: repository.root)
        }
    }

    func openRepository() {
        guard !isOpening else { return }

        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.prompt = String(localized: "Open repository")

        guard panel.runModal() == .OK else { return }

        let folders = panel.urls

        Task { await open(folders) }
    }

    func open(_ folders: [URL]) async {
        guard !isOpening else { return }

        isOpening = true
        error = nil
        var failures: [String] = []

        defer { isOpening = false }

        for folder in folders {
            do {
                let snapshot = try await service.snapshot(at: folder)
                let root = snapshot.root.resolvingSymlinksInPath().standardizedFileURL

                if let existing = repositories.first(where: { $0.root == root }) {
                    await existing.branches.load(at: root)
                } else {
                    let canonicalSnapshot = GitRepositorySnapshot(root: root, currentBranch: snapshot.currentBranch, branches: snapshot.branches, remotes: snapshot.remotes)
                    repositories.append(RepositorySession(root: root, snapshot: canonicalSnapshot))
                }

                selectedID = root
                persist()
            } catch {
                failures.append(folder.path + "\n" + error.localizedDescription)
            }
        }

        if !failures.isEmpty {
            error = failures.joined(separator: "\n\n")
        }
    }

    func select(_ repository: RepositorySession) {
        guard repositories.contains(where: { $0.id == repository.id }) else { return }

        selectedID = repository.id
        persist()

        if repository.branches.repository != nil {
            repository.branches.refresh()
        }
    }

    func close(_ repository: RepositorySession) {
        guard !repository.branches.isBusy,
              let index = repositories.firstIndex(where: { $0.id == repository.id }) else { return }

        repositories.remove(at: index)

        if selectedID == repository.id {
            selectedID = repositories.isEmpty ? nil : repositories[min(index, repositories.count - 1)].id
        }

        persist()
    }
}

private extension RepositoryWorkspaceStore {
    nonisolated struct SavedWorkspace: Codable {
        let paths: [String]
        let selectedPath: String?
    }

    func persist() {
        let saved = SavedWorkspace(paths: repositories.map(\.root.path), selectedPath: selectedID?.path)

        guard let data = try? JSONEncoder().encode(saved) else { return }

        defaults.set(data, forKey: Self.persistenceKey)
    }
}
