import Foundation
import Observation

@MainActor
@Observable
final class BranchStore {
    private(set) var repository: GitRepositorySnapshot? {
        didSet { revision = UUID() }
    }

    private(set) var revision = UUID()
    private(set) var isBusy = false
    var error: String?
    var selectedRemote = ""
    private let service = GitBranchService()

    var branchLabel: String {
        guard let repository else { return String(localized: "No repository") }

        return repository.currentBranch ?? String(localized: "Detached HEAD")
    }

    init(repository: GitRepositorySnapshot? = nil) {
        self.repository = repository
        selectedRemote = repository?.remotes.contains("origin") == true ? "origin" : repository?.remotes.first ?? ""
    }

    func load(at root: URL) async {
        guard !isBusy else { return }

        error = nil
        isBusy = true

        defer { isBusy = false }

        do {
            repository = try await service.snapshot(at: root)

            if let remotes = repository?.remotes, !remotes.contains(selectedRemote) {
                selectedRemote = remotes.contains("origin") ? "origin" : remotes.first ?? ""
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func refresh() {
        guard let root = repository?.root else { return }

        perform { try await self.service.snapshot(at: root) }
    }

    func create(_ name: String) async -> Bool {
        guard !isBusy, let root = repository?.root else { return false }

        error = nil
        isBusy = true

        defer { isBusy = false }

        do {
            try await service.create(name, at: root)
            repository = try await service.snapshot(at: root)
            return true
        } catch {
            self.error = error.localizedDescription
            repository = try? await service.snapshot(at: root)
            return false
        }
    }

    func checkout(_ branch: GitBranch) {
        mutate { root in try await self.service.checkout(branch, at: root) }
    }

    func rename(_ branch: GitBranch, to name: String) {
        mutate { root in try await self.service.rename(branch, to: name, at: root) }
    }

    func delete(_ branch: GitBranch) {
        mutate { root in try await self.service.delete(branch, at: root) }
    }

    func fetch() {
        mutate { root in try await self.service.fetch(at: root) }
    }

    func stage(_ file: GitWorkingFile?) {
        mutate { root in try await self.service.stage(file, at: root) }
    }

    func unstage(_ file: GitWorkingFile) {
        mutate { root in try await self.service.unstage(file, at: root) }
    }

    func commit(_ message: String) async -> Bool {
        guard !isBusy, let root = repository?.root else { return false }

        error = nil
        isBusy = true

        defer { isBusy = false }

        do {
            try await service.commit(message, at: root)
        } catch {
            self.error = error.localizedDescription
            repository = try? await service.snapshot(at: root)

            return false
        }

        // A refresh failure must not imply the commit failed or invite a duplicate.
        do {
            repository = try await service.snapshot(at: root)
        } catch {
            self.error = error.localizedDescription
        }

        return true
    }

    func push() {
        guard let branch = repository?.currentBranch, !selectedRemote.isEmpty else { return }

        let remote = selectedRemote

        mutate { root in try await self.service.push(branch, to: remote, at: root) }
    }
}

private extension BranchStore {
    func mutate(_ operation: @escaping @MainActor (URL) async throws -> Void) {
        guard let root = repository?.root else { return }

        perform {
            do {
                try await operation(root)
            } catch {
                // Failed operations can still update refs (for example a partial fetch).
                self.repository = try? await self.service.snapshot(at: root)
                throw error
            }

            return try await self.service.snapshot(at: root)
        }
    }

    func perform(_ operation: @escaping @MainActor () async throws -> GitRepositorySnapshot) {
        guard !isBusy else { return }

        error = nil
        isBusy = true

        Task {
            defer { isBusy = false }

            do {
                repository = try await operation()

                if let remotes = repository?.remotes, !remotes.contains(selectedRemote) {
                    selectedRemote = remotes.contains("origin") ? "origin" : remotes.first ?? ""
                }
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}
