import Foundation

@main
@MainActor
struct RepositoryWorkspaceIntegration {
    static func main() async throws {
        if CommandLine.arguments.count > 1 {
            try await verifyRelaunch()
            return
        }

        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("GitKutulhu-workspace-" + UUID().uuidString).resolvingSymlinksInPath()
        let suite = "GitKutulhu-workspace-tests-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        defer {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: folder)
        }

        let first = folder.appendingPathComponent("First dépôt", isDirectory: true)
        let second = folder.appendingPathComponent("Second repo", isDirectory: true)
        let invalid = folder.appendingPathComponent("Not a repository", isDirectory: true)
        let alias = folder.appendingPathComponent("Alias", isDirectory: true)
        let nested = first.appendingPathComponent("nested", isDirectory: true)
        try git(["init", "--initial-branch=main", first.path], at: folder)
        try git(["init", "--initial-branch=other", second.path], at: folder)
        try FileManager.default.createDirectory(at: invalid, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: first)

        let store = RepositoryWorkspaceStore(defaults: defaults)
        precondition(store.repositories.isEmpty && store.selectedRepository == nil)
        await store.open([first, invalid, second])
        precondition(store.repositories.map(\.root) == [first, second])
        precondition(store.selectedID == second && store.error != nil && !store.isOpening)
        let firstSession = store.repositories[0]
        let secondSession = store.repositories[1]
        precondition(firstSession.branches.repository?.currentBranch == "main")
        precondition(secondSession.branches.repository?.currentBranch == "other")

        await firstSession.changes.reload(at: first)
        await secondSession.changes.reload(at: second)
        firstSession.changes.message = "First draft"
        secondSession.changes.message = "Second draft"
        firstSession.search = "first filter"
        firstSession.section = .changes
        await store.open([alias, nested, first])
        precondition(store.repositories.count == 2 && store.selectedID == first)
        precondition(store.repositories[0] === firstSession)
        precondition(firstSession.changes.message == "First draft")
        precondition(secondSession.changes.message == "Second draft")

        store.select(secondSession)
        store.select(firstSession)
        precondition(firstSession.search == "first filter" && firstSession.section == .changes)

        // A separate process must read the saved list and last selected tab.
        defaults.synchronize()
        let child = Process()
        child.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
        child.arguments = [suite, first.path, second.path]
        try child.run()
        child.waitUntilExit()
        precondition(child.terminationStatus == 0)

        // Unavailable folders remain saved and can be retried after recovery.
        let moved = folder.appendingPathComponent("temporarily moved", isDirectory: true)
        try FileManager.default.moveItem(at: second, to: moved)
        let restored = RepositoryWorkspaceStore(defaults: defaults)
        await restored.restore()
        precondition(restored.repositories.count == 2 && restored.selectedID == first)
        let unavailable = restored.repositories[1]
        precondition(unavailable.branches.repository == nil && unavailable.branches.error != nil)
        let savedWhileMissing = RepositoryWorkspaceStore(defaults: defaults)
        precondition(savedWhileMissing.repositories.count == 2)
        try FileManager.default.moveItem(at: moved, to: second)
        await unavailable.branches.load(at: second)
        precondition(unavailable.branches.repository?.currentBranch == "other" && unavailable.branches.error == nil)

        restored.close(restored.repositories[0])
        precondition(restored.selectedID == second)
        var reopened = RepositoryWorkspaceStore(defaults: defaults)
        precondition(reopened.repositories.map(\.root) == [second] && reopened.selectedID == second)
        restored.close(unavailable)
        reopened = RepositoryWorkspaceStore(defaults: defaults)
        precondition(reopened.repositories.isEmpty && reopened.selectedID == nil)

        // Linked worktrees must stay distinct from their main repository.
        try git(["-c", "user.name=Test", "-c", "user.email=test@example.invalid", "commit", "--allow-empty", "-m", "Initial"], at: first)
        let worktree = folder.appendingPathComponent("Linked worktree", isDirectory: true)
        try git(["worktree", "add", "-b", "linked", worktree.path], at: first)
        await reopened.open([first, worktree])
        precondition(reopened.repositories.map(\.root) == [first, worktree])

        defaults.set(Data("invalid JSON".utf8), forKey: "repositoryWorkspace.v1")
        precondition(RepositoryWorkspaceStore(defaults: defaults).repositories.isEmpty)
        print("Repository workspace integration checks passed")
    }
}

private extension RepositoryWorkspaceIntegration {
    static func verifyRelaunch() async throws {
        let arguments = CommandLine.arguments
        let store = RepositoryWorkspaceStore(defaults: UserDefaults(suiteName: arguments[1])!)
        let first = URL(fileURLWithPath: arguments[2], isDirectory: true)
        let second = URL(fileURLWithPath: arguments[3], isDirectory: true)
        precondition(store.repositories.map(\.root) == [first, second] && store.selectedID == first)

        await store.restore()
        precondition(store.repositories[0].branches.repository?.currentBranch == "main")
        precondition(store.repositories[1].branches.repository?.currentBranch == "other")
        precondition(store.repositories.allSatisfy(\.changes.message.isEmpty))
        print("Cross-process repository restoration passed")
    }

    static func git(_ arguments: [String], at root: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments
        process.currentDirectoryURL = root
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw GitOperationError(errorDescription: "Fixture Git operation failed: " + arguments.joined(separator: " "))
        }
    }
}
