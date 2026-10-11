import Foundation

@main
@MainActor
struct ChangesIntegration {
    static func main() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("GitKutulhu-changes-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try git(["init", "--initial-branch=main"], at: root)
        try git(["config", "user.name", "Changes Test"], at: root)
        try git(["config", "user.email", "changes@example.invalid"], at: root)
        try git(["config", "commit.gpgsign", "false"], at: root)
        let service = GitBranchService()
        let clean = try await service.workingChanges(at: root)
        precondition(clean.isEmpty)

        // Paths are NUL-delimited and passed as literal arguments, including pathspec syntax.
        let paths = ["café\tline\nfile.txt", ":(glob)*.txt", "-option.txt", "[abc].txt", "space name.txt"]
        for path in paths {
            try write("first\nsecond\n", path, at: root)
        }
        try write("ignored\n", "ignored.txt", at: root)
        try write("ignored.txt\n", ".gitignore", at: root)
        var files = try await service.workingChanges(at: root)
        precondition(files.count == 6 && !files.contains { $0.path == "ignored.txt" })
        precondition(Set(files.map(\.path)).isSuperset(of: paths))
        for path in paths {
            let file = files.first { $0.path == path }!
            let diff = try await service.workingDiff(for: file, at: root)
            precondition(diff.contains("+first\n+second"))
            try await service.stage(file, at: root)
        }
        files = try await service.workingChanges(at: root)
        precondition(files.filter(\.staged).count == paths.count)
        let staged = files.first { $0.path == paths[0] }!
        try write("changed after staging\n", paths[0], at: root)
        // Unstage on an unborn branch, preserving newer working-copy content.
        try await service.unstage(staged, at: root)
        try check(try String(contentsOf: root.appendingPathComponent(paths[0]), encoding: .utf8) == "changed after staging\n")
        files = try await service.workingChanges(at: root)
        precondition(!files.contains { $0.path == paths[0] && $0.staged })
        try await service.stage(nil, at: root)
        try await service.commit("Initial commit\n\nBody with $(literal) and `text`", at: root)
        let initial = try git(["log", "-1", "--format=%B"], at: root)
        precondition(initial.contains("Body with $(literal) and `text`"))
        let afterInitial = try await service.workingChanges(at: root)
        precondition(afterInitial.isEmpty)

        let path = "space name.txt"
        try write("staged\nsecond\n", path, at: root)
        files = try await service.workingChanges(at: root)
        try await service.stage(files.first { $0.path == path }!, at: root)
        try write("unstaged\nsecond\n", path, at: root)
        files = try await service.workingChanges(at: root)
        let sides = files.filter { $0.path == path }
        precondition(sides.count == 2 && Set(sides.map(\.staged)) == [true, false])
        let indexDiff = try await service.workingDiff(for: sides.first { $0.staged }!, at: root)
        let workDiff = try await service.workingDiff(for: sides.first { !$0.staged }!, at: root)
        precondition(indexDiff.contains("+staged") && !indexDiff.contains("+unstaged"))
        precondition(workDiff.contains("-staged") && workDiff.contains("+unstaged"))
        let rows = GitDiffRow.split(indexDiff)
        precondition(rows.contains { $0.before == "first" && $0.after == "staged" && $0.oldLine == 1 && $0.newLine == 1 })
        precondition(rows.contains { $0.before == "second" && $0.after == "second" && !$0.changed && $0.newLine == 2 })
        try await service.commit("Only the index", at: root)
        try check(try git(["show", "HEAD:" + path], at: root) == "staged\nsecond\n")
        try check(try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8) == "unstaged\nsecond\n")
        files = try await service.workingChanges(at: root)
        try await service.stage(files.first { $0.path == path }!, at: root)
        files = try await service.workingChanges(at: root)
        try await service.unstage(files.first { $0.path == path }!, at: root)
        try check(try git(["diff", "--cached"], at: root).isEmpty)

        // Deletion, renames represented as delete/add, and binary changes.
        try FileManager.default.removeItem(at: root.appendingPathComponent(paths[0]))
        try FileManager.default.moveItem(at: root.appendingPathComponent("-option.txt"), to: root.appendingPathComponent("renamed.txt"))
        try Data([0, 1, 0, 2]).write(to: root.appendingPathComponent("binary.dat"))
        files = try await service.workingChanges(at: root)
        precondition(files.contains { $0.path == paths[0] && $0.status == "D" })
        let binary = files.first { $0.path == "binary.dat" }!
        let binaryDiff = try await service.workingDiff(for: binary, at: root)
        precondition(binaryDiff.contains("Binary files"))
        try await service.stage(nil, at: root)
        files = try await service.workingChanges(at: root)
        precondition(files.allSatisfy(\.staged))
        precondition(files.contains { $0.path == "-option.txt" && $0.status == "D" })
        precondition(files.contains { $0.path == "renamed.txt" && $0.status == "A" })

        // Hook rejection surfaces Git's message and retains index and draft.
        try write("#!/bin/sh\necho 'Commit rejected by test hook' >&2\nexit 1\n", ".git/hooks/pre-commit", at: root)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: root.appendingPathComponent(".git/hooks/pre-commit").path)
        do {
            try await service.commit("Rejected", at: root)
            preconditionFailure("Hook must reject commit")
        } catch { precondition(error.localizedDescription.contains("Commit rejected by test hook")) }
        let afterFailure = try await service.workingChanges(at: root)
        precondition(afterFailure == files)
        try FileManager.default.removeItem(at: root.appendingPathComponent(".git/hooks/pre-commit"))
        try await service.commit("Changes", at: root)

        // Real conflict status is explicit, with no fabricated staged entry.
        try write("base\n", "conflict.txt", at: root)
        try await service.stage(nil, at: root)
        try await service.commit("Conflict base", at: root)
        try git(["switch", "-c", "other"], at: root)
        try write("other\n", "conflict.txt", at: root)
        try await service.stage(nil, at: root)
        try await service.commit("Other", at: root)
        try git(["switch", "main"], at: root)
        try write("main\n", "conflict.txt", at: root)
        try await service.stage(nil, at: root)
        try await service.commit("Main", at: root)
        do { try git(["merge", "other"], at: root); preconditionFailure("Expected conflict") } catch {}
        files = try await service.workingChanges(at: root)
        precondition(files.count == 1 && files[0].conflicted && !files[0].staged)
        let store = ChangesStore()
        await store.reload(at: root)
        precondition(store.hasConflicts && store.stagedCount == 0 && !store.isLoading)
        store.message = "Keep draft"
        await store.reload(at: root)
        precondition(store.message == "Keep draft")
        await store.reload(at: nil)
        precondition(store.files.isEmpty && store.patch.isEmpty && store.message.isEmpty && store.selectedID == nil)
        await store.reload(at: root.appendingPathComponent("missing"))
        precondition(store.error != nil && !store.isLoading)
        print("Changes integration checks passed")
    }
}

private extension ChangesIntegration {
    static func check(_ condition: @autoclosure () throws -> Bool) rethrows {
        let result = try condition()
        precondition(result)
    }

    static func write(_ text: String, _ path: String, at root: URL) throws {
        try text.write(to: root.appendingPathComponent(path), atomically: true, encoding: .utf8)
    }

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
        return output
    }
}
