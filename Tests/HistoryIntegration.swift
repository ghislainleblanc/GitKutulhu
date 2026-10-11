import Foundation

@main
@MainActor
struct HistoryIntegration {
    static func main() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("GitKutulhu-history-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try git(["init", "--initial-branch=main"], at: root)
        try git(["config", "user.name", "Auteur Test"], at: root)
        try git(["config", "user.email", "history@example.invalid"], at: root)
        try git(["config", "commit.gpgsign", "false"], at: root)
        let service = GitBranchService()
        let empty = try await service.history(at: root, skip: 0)
        precondition(empty.isEmpty)

        let unusual = "café\tline\nfile.txt"
        try "first\nsecond\n".write(to: root.appendingPathComponent(unusual), atomically: true, encoding: .utf8)
        try Data([0, 1, 2, 0]).write(to: root.appendingPathComponent("binary.dat"))
        try git(["add", "--all"], at: root)
        try git(["commit", "-m", "Initial café", "-m", "Full body\nSecond line"], at: root)
        let initial = try await service.history(at: root, skip: 0)
        precondition(initial.count == 1)
        precondition(initial[0].author == "Auteur Test" && initial[0].email == "history@example.invalid")
        precondition(initial[0].message.contains("Full body\nSecond line"))
        precondition(initial[0].date.timeIntervalSince1970 > 0 && initial[0].parents.isEmpty)
        let rootFiles = try await service.changedFiles(for: initial[0], at: root)
        precondition(rootFiles.first { $0.id == unusual }?.additions == 2)
        precondition(rootFiles.first { $0.id == "binary.dat" }?.additions == nil)
        precondition(rootFiles.count == 2)

        try git(["switch", "-c", "feature"], at: root)
        try "feature\n".write(to: root.appendingPathComponent("feature.txt"), atomically: true, encoding: .utf8)
        try git(["add", "--all"], at: root)
        try git(["commit", "-m", "Feature"], at: root)
        try git(["switch", "main"], at: root)
        try git(["commit", "--allow-empty", "-m", "Main"], at: root)
        try git(["merge", "--no-ff", "feature", "-m", "Merge feature"], at: root)
        var commits = try await service.history(at: root, skip: 0)
        precondition(commits.count == 4 && commits[0].parents.count == 2)
        let mergeFiles = try await service.changedFiles(for: commits[0], at: root)
        precondition(mergeFiles.count == 1 && mergeFiles[0].id == "feature.txt" && mergeFiles[0].additions == 1)
        let mainCommit = commits.first { $0.title == "Main" }!
        let noFiles = try await service.changedFiles(for: mainCommit, at: root)
        precondition(noFiles.isEmpty)
        let graph = CommitGraph.layout(commits)
        precondition(graph[0].incoming.isEmpty && graph[0].outgoing.count == 2)
        precondition(graph.last!.outgoing.isEmpty && graph.map(\.width).max()! >= 2)
        for index in 0 ..< commits.count - 1 {
            let bottom = Set(graph[index].outgoing + graph[index].passing.map(\.1))
            let top = Set(graph[index + 1].incoming + graph[index + 1].passing.map(\.0))
            precondition(bottom == top, "Graph connections must meet between adjacent rows")
        }

        try git(["checkout", "--detach"], at: root)
        try git(["commit", "--allow-empty", "-m", "Detached tip"], at: root)
        commits = try await service.history(at: root, skip: 0)
        precondition(commits.first!.title == "Detached tip")
        try git(["update-ref", "refs/remotes/origin/other", commits[0].id], at: root)
        try git(["switch", "main"], at: root)
        commits = try await service.history(at: root, skip: 0)
        precondition(commits.contains { $0.title == "Detached tip" && $0.references.contains("origin/other") })

        for index in 0 ..< 202 {
            try git(["commit", "--allow-empty", "-m", "Page \(index)"], at: root)
        }
        let first = try await service.history(at: root, skip: 0)
        let next = try await service.history(at: root, skip: 200)
        precondition(first.count == 201 && !next.isEmpty)
        precondition(first[200].id == next[0].id)
        precondition(Set(first.prefix(200).map(\.id)).isDisjoint(with: next.map(\.id)))

        let store = HistoryStore()
        await store.reload(at: root)
        precondition(store.commits.count == 200 && store.hasMore && !store.isLoading)
        await store.loadMore(at: root)
        precondition(store.commits.count == 207 && !store.hasMore)
        store.selectedID = initial[0].id
        await store.loadFiles(at: root, commit: initial[0])
        precondition(store.files.count == 2 && !store.isLoadingFiles)
        await store.reload(at: nil)
        precondition(store.commits.isEmpty && store.files.isEmpty && store.selectedID == nil)
        await store.reload(at: root.appendingPathComponent("missing"))
        precondition(store.error != nil && !store.isLoading)
        print("History integration checks passed")
    }
}

private extension HistoryIntegration {
    @discardableResult
    static func git(_ arguments: [String], at root: URL) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments
        process.currentDirectoryURL = root
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let output = String(decoding: data, as: UTF8.self)
        guard process.terminationStatus == 0 else { throw GitOperationError(errorDescription: output) }
        return output.trimmingCharacters(in: .newlines)
    }
}
