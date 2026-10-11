import Foundation

@main
@MainActor
struct BranchIntegration {
    static func main() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("GitKutulhu-tests-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        defer { try? FileManager.default.removeItem(at: folder) }

        let remote = folder.appendingPathComponent("remote.git")
        let clone = folder.appendingPathComponent("clone")
        let peer = folder.appendingPathComponent("peer")

        try git(["init", "--bare", "--initial-branch=main", remote.path], at: folder)
        try git(["clone", remote.path, clone.path], at: folder)
        try git(["config", "user.name", "Integration Test"], at: clone)
        try git(["config", "user.email", "test@example.invalid"], at: clone)
        try "initial\n".write(to: clone.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        try git(["add", "file.txt"], at: clone)
        try git(["commit", "-m", "Initial"], at: clone)

        let service = GitBranchService()
        try await service.push("main", to: "origin", at: clone)
        var state = try await service.snapshot(at: clone)
        precondition(state.currentBranch == "main")
        precondition(state.branches.contains { $0.name == "main" && $0.upstream == "origin/main" })

        try await service.create("feature/real-branch", at: clone)
        try await service.push("feature/real-branch", to: "origin", at: clone)
        let published = try git(["show-ref", "refs/heads/feature/real-branch"], at: remote)
        precondition(published.contains("refs/heads/feature/real-branch"))

        state = try await service.snapshot(at: clone)
        let main = state.branches.first { $0.name == "main" && $0.remote == nil }!
        let feature = state.branches.first { $0.name == "feature/real-branch" && $0.remote == nil }!

        try await service.checkout(main, at: clone)
        try await service.rename(feature, to: "feature/renamed", at: clone)

        state = try await service.snapshot(at: clone)
        let renamed = state.branches.first { $0.name == "feature/renamed" && $0.remote == nil }!
        try await service.delete(renamed, at: clone)

        try await service.fetch(at: clone)
        state = try await service.snapshot(at: clone)
        let remoteBranch = state.branches.first { $0.name == "feature/real-branch" && $0.remote == "origin" }!
        try await service.checkout(remoteBranch, at: clone)

        state = try await service.snapshot(at: clone)
        precondition(state.currentBranch == "feature/real-branch")
        precondition(state.branches.contains { $0.name == "feature/real-branch" && $0.upstream == "origin/feature/real-branch" })

        for invalid in ["--force", "@{-1}", "bad..name", "HEAD", "a b"] {
            try await expectFailure { try await service.create(invalid, at: clone) }
        }
        try await expectFailure { try await service.create("main", at: clone) }

        // Dirty checkout must fail without losing the file or changing HEAD.
        try "feature\n".write(to: clone.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        try git(["commit", "-am", "Feature change"], at: clone)
        try "uncommitted\n".write(to: clone.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        try await expectFailure { try await service.checkout(main, at: clone) }
        let dirtyContents = try String(contentsOf: clone.appendingPathComponent("file.txt"), encoding: .utf8)
        precondition(dirtyContents == "uncommitted\n")

        // Restore only the disposable test fixture.
        try git(["restore", "file.txt"], at: clone)

        try await service.checkout(main, at: clone)
        try await expectFailure { try await service.delete(feature, at: clone) }
        try await expectFailure { try await service.delete(main, at: clone) }

        // Another clone advances the remote; ordinary push must reject divergence.
        try git(["clone", remote.path, peer.path], at: folder)
        try git(["config", "user.name", "Integration Test"], at: peer)
        try git(["config", "user.email", "test@example.invalid"], at: peer)
        try "peer\n".write(to: peer.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        try git(["commit", "-am", "Peer change"], at: peer)
        try git(["push", "origin", "main"], at: peer)
        try await expectFailure { try await service.push("main", to: "origin", at: clone) }

        // Fetch sees additions and prunes branches deleted on the remote.
        try git(["branch", "remote-only"], at: peer)
        try git(["push", "origin", "remote-only", ":feature/real-branch"], at: peer)

        try await service.fetch(at: clone)
        state = try await service.snapshot(at: clone)
        precondition(state.branches.contains { $0.name == "remote-only" && $0.remote == "origin" })
        precondition(!state.branches.contains { $0.name == "feature/real-branch" && $0.remote != nil })

        let linked = folder.appendingPathComponent("linked")
        try git(["worktree", "add", "-b", "linked-work", linked.path], at: clone)
        let linkedState = try await service.snapshot(at: linked)
        precondition(linkedState.root.resolvingSymlinksInPath() == linked.resolvingSymlinksInPath())
        precondition(linkedState.currentBranch == "linked-work")
        let linkedBranch = linkedState.branches.first { $0.name == "linked-work" }!
        try await expectFailure { try await service.checkout(linkedBranch, at: clone) }
        try await expectFailure { try await service.delete(linkedBranch, at: clone) }

        try git(["checkout", "--detach"], at: clone)

        state = try await service.snapshot(at: clone)
        precondition(state.currentBranch == nil)
        try await expectFailure { _ = try await service.snapshot(at: folder) }

        if ProcessInfo.processInfo.environment["GITKUTULHU_TEST_GITHUB"] == "1" {
            let github = folder.appendingPathComponent("github")
            try git(["init", github.path], at: folder)
            try git(["remote", "add", "origin", "https://github.com/octocat/Hello-World.git"], at: github)
            try await service.fetch(at: github)
            let githubState = try await service.snapshot(at: github)
            precondition(githubState.branches.contains { $0.remote == "origin" })
            let remoteBranch = githubState.branches.first { $0.remote == "origin" }!
            try await service.checkout(remoteBranch, at: github)
            let checkedOut = try await service.snapshot(at: github)
            precondition(checkedOut.currentBranch == remoteBranch.name)
            print("PASS: live GitHub HTTPS fetch and tracking checkout (public repository)")
        }

        print("PASS: real Git branch integration, tracking, fetch/prune, push rejection, dirty-file preservation, validation, detached HEAD")
    }
}

private extension BranchIntegration {
    static func expectFailure(_ operation: () async throws -> Void) async throws {
        do {
            try await operation()
        } catch { return }

        fatalError("Expected Git operation to fail")
    }

    @discardableResult
    static func git(_ arguments: [String], at folder: URL) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments
        process.currentDirectoryURL = folder

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        let output = String(decoding: data, as: UTF8.self)

        guard process.terminationStatus == 0 else { throw GitOperationError(errorDescription: output) }

        return output
    }
}
