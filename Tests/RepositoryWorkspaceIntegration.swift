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

        // Clone through the same store as the UI, then verify disk state and restoration.
        try "Cloned contents\n".write(to: first.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        try git(["add", "file.txt"], at: first)
        try git(["-c", "user.name=Test", "-c", "user.email=test@example.invalid", "commit", "-m", "Clone fixture"], at: first)
        let remote = folder.appendingPathComponent("Remote dépôt.git", isDirectory: true)
        try git(["clone", "--bare", first.path, remote.path], at: folder)
        let destination = folder.appendingPathComponent("Cloned dépôt $(literal)", isDirectory: true)
        let cloned = await reopened.clone("  " + remote.absoluteString + "\n", to: destination)
        precondition(cloned && !reopened.isBusy && reopened.cloneError == nil)
        precondition(reopened.repositories.count == 3 && reopened.selectedID == destination)
        let snapshot = reopened.selectedRepository!.branches.repository!
        precondition(snapshot.currentBranch == "main" && snapshot.remotes == ["origin"])
        precondition(snapshot.branches.contains { $0.name == "main" && $0.remote == nil && $0.upstream == "origin/main" })
        let contents = try String(contentsOf: destination.appendingPathComponent("file.txt"), encoding: .utf8)
        precondition(contents == "Cloned contents\n")
        let afterClone = RepositoryWorkspaceStore(defaults: defaults)
        precondition(afterClone.selectedID == destination && afterClone.repositories.count == 3)
        await afterClone.restore()
        precondition(afterClone.selectedRepository?.branches.repository?.currentBranch == "main")

        // Existing destinations (including empty folders and symlinks) are preserved.
        for occupied in [destination, invalid, alias] {
            let succeeded = await reopened.clone(remote.path, to: occupied)
            precondition(!succeeded && reopened.cloneError != nil && !reopened.isBusy)
            precondition(reopened.repositories.count == 3 && reopened.selectedID == destination)
        }
        let preserved = try String(contentsOf: destination.appendingPathComponent("file.txt"), encoding: .utf8)
        precondition(preserved == contents)
        let dangling = folder.appendingPathComponent("Dangling alias")
        try FileManager.default.createSymbolicLink(at: dangling, withDestinationURL: folder.appendingPathComponent("missing"))
        let reusedLink = await reopened.clone(remote.path, to: dangling)
        precondition(!reusedLink && reopened.cloneError != nil)

        // Bad sources fail without adding a tab, and a later retry succeeds.
        let retryDestination = folder.appendingPathComponent("Retry clone", isDirectory: true)
        for source in [" \n", folder.appendingPathComponent("Missing remote").path, "--upload-pack=invalid"] {
            let succeeded = await reopened.clone(source, to: retryDestination)
            precondition(!succeeded && reopened.cloneError != nil && !reopened.isBusy)
            precondition(reopened.repositories.count == 3 && reopened.selectedID == destination)
        }
        let retried = await reopened.clone(remote.path, to: retryDestination)
        precondition(retried && reopened.cloneError == nil && reopened.selectedID == retryDestination)

        let emptyRemote = folder.appendingPathComponent("Empty.git", isDirectory: true)
        try git(["init", "--bare", "--initial-branch=main", emptyRemote.path], at: folder)
        let emptyDestination = folder.appendingPathComponent("Empty clone", isDirectory: true)
        let emptyCloned = await reopened.clone(emptyRemote.path, to: emptyDestination)
        precondition(emptyCloned && reopened.selectedRepository?.branches.repository?.branches.isEmpty == true)

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
