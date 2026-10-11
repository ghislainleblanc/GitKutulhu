import Foundation

nonisolated struct GitBranch: Identifiable, Sendable, Equatable {
    let name: String
    let ref: String
    let upstream: String
    let remote: String?

    var id: String {
        ref
    }
}

nonisolated struct GitRepositorySnapshot: Sendable {
    let root: URL
    let currentBranch: String?
    let branches: [GitBranch]
    let remotes: [String]
}

nonisolated struct GitOperationError: LocalizedError {
    let errorDescription: String?
}

/// Runs Git away from the main actor. Arguments never pass through a shell.
actor GitBranchService {
    func snapshot(at folder: URL) throws -> GitRepositorySnapshot {
        let rootPath = try run(["rev-parse", "--show-toplevel"], at: folder)
        let root = URL(fileURLWithPath: rootPath, isDirectory: true)

        let current = try run(["symbolic-ref", "--quiet", "--short", "HEAD"], at: root, allowedStatuses: [0, 1])
        let remotes = try run(["remote"], at: root).components(separatedBy: "\n").filter { !$0.isEmpty }
        let output = try run(["for-each-ref", "--sort=refname", "--format=%(refname)%09%(upstream:short)%09%(symref)", "refs/heads/", "refs/remotes/"], at: root)

        let branches = output.split(separator: "\n").compactMap { line -> GitBranch? in
            let fields = line.components(separatedBy: "\t")

            guard fields.count == 3, fields[2].isEmpty else { return nil }

            let ref = fields[0]

            if ref.hasPrefix("refs/heads/") {
                return GitBranch(name: String(ref.dropFirst("refs/heads/".count)), ref: ref, upstream: fields[1], remote: nil)
            }

            let short = String(ref.dropFirst("refs/remotes/".count))

            guard let remote = remotes.sorted(by: { $0.count > $1.count }).first(where: { short.hasPrefix($0 + "/") }) else { return nil }

            return GitBranch(name: String(short.dropFirst(remote.count + 1)), ref: ref, upstream: "", remote: remote)
        }

        return GitRepositorySnapshot(root: root, currentBranch: current.isEmpty ? nil : current, branches: branches, remotes: remotes)
    }

    func history(at root: URL, skip: Int) throws -> [GitCommit] {
        let head = try run(["rev-parse", "--verify", "--quiet", "HEAD"], at: root, allowedStatuses: [0, 1])
        var arguments = ["log", "--all", "--topo-order", "--max-count=201", "--skip=\(skip)", "--no-show-signature", "--decorate=short", "--format=%H%x00%P%x00%an%x00%ae%x00%at%x00%s%x00%B%x00%D", "-z"]
        if !head.isEmpty {
            arguments.append("HEAD")
        }
        arguments.append("--")
        let output = try run(arguments, at: root)
        let fields = output.components(separatedBy: "\0")
        return stride(from: 0, to: fields.count - 1, by: 8).compactMap { index in
            guard index + 7 < fields.count, let timestamp = Double(fields[index + 4]) else { return nil }
            return GitCommit(id: fields[index], parents: fields[index + 1].split(separator: " ").map(String.init), author: fields[index + 2], email: fields[index + 3], date: Date(timeIntervalSince1970: timestamp), title: fields[index + 5], message: fields[index + 6].trimmingCharacters(in: .newlines), references: fields[index + 7])
        }
    }

    func changedFiles(for commit: GitCommit, at root: URL) throws -> [GitCommitFile] {
        let arguments: [String] = if let parent = commit.parents.first {
            // Merge summaries compare with the first parent, including merge resolutions.
            ["diff", "--numstat", "-z", "--no-renames", "--no-ext-diff", "--no-textconv", parent, commit.id, "--"]
        } else {
            ["diff-tree", "--root", "--no-commit-id", "-r", "--numstat", "-z", "--no-renames", "--no-ext-diff", "--no-textconv", commit.id, "--"]
        }
        return try run(arguments, at: root).split(separator: "\0").compactMap { record in
            let fields = record.split(separator: "\t", maxSplits: 2, omittingEmptySubsequences: false)
            guard fields.count == 3 else { return nil }
            return GitCommitFile(id: String(fields[2]), additions: Int(fields[0]), deletions: Int(fields[1]))
        }
    }

    func create(_ name: String, at root: URL) throws {
        try validate(name, at: root)

        try run(["switch", "--no-guess", "-c", name], at: root)
    }

    func checkout(_ branch: GitBranch, at root: URL) throws {
        try validate(branch.name, at: root)

        if branch.remote != nil {
            // Explicit full reference prevents guessing between remotes or tags.
            try run(["switch", "--no-guess", "--track", "-c", branch.name, branch.ref], at: root)
        } else {
            try run(["switch", "--no-guess", "--", branch.name], at: root)
        }
    }

    func rename(_ branch: GitBranch, to name: String, at root: URL) throws {
        try requireLocal(branch)
        try validate(name, at: root)

        try run(["branch", "-m", "--", branch.name, name], at: root)
    }

    func delete(_ branch: GitBranch, at root: URL) throws {
        try requireLocal(branch)

        // No force deletion: Git protects unmerged branches and other worktrees.
        try run(["branch", "-d", "--", branch.name], at: root)
    }

    func fetch(at root: URL) throws {
        try run(["fetch", "--all", "--prune"], at: root)
    }

    func push(_ branch: String, to remote: String, at root: URL) throws {
        try validate(branch, at: root)

        let remotes = try run(["remote"], at: root).components(separatedBy: "\n")

        guard remotes.contains(remote), !remote.hasPrefix("-") else {
            throw GitOperationError(errorDescription: String(localized: "Choose a configured remote."))
        }

        // Explicit refspec publishes only this branch; never force-push.
        try run(["push", "--set-upstream", "--", remote, "refs/heads/\(branch):refs/heads/\(branch)"], at: root)
    }
}

private extension GitBranchService {
    func requireLocal(_ branch: GitBranch) throws {
        guard branch.remote == nil else {
            throw GitOperationError(errorDescription: String(localized: "Only local branches can be renamed or deleted."))
        }
    }

    func validate(_ name: String, at root: URL) throws {
        guard !name.isEmpty, !name.hasPrefix("-"), name != "HEAD", !name.contains("@{"),
              !name.contains(where: \.isWhitespace)
        else {
            throw GitOperationError(errorDescription: String(localized: "Enter a valid Git branch name."))
        }

        // Validate a full ref to reject checkout shortcuts such as @{-1}.
        do {
            try run(["check-ref-format", "refs/heads/" + name], at: root)
        } catch is GitOperationError {
            throw GitOperationError(errorDescription: String(localized: "Enter a valid Git branch name."))
        }
    }

    @discardableResult
    func run(_ arguments: [String], at root: URL, allowedStatuses: Set<Int32> = [0]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments
        process.currentDirectoryURL = root

        var environment = ProcessInfo.processInfo.environment
        environment["GIT_TERMINAL_PROMPT"] = "0"
        environment["GIT_SSH_COMMAND"] = "/usr/bin/ssh -oBatchMode=yes -oConnectTimeout=15"
        environment["LC_ALL"] = "C"
        // Finder-launched apps otherwise cannot find common credential helpers.
        environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

        process.environment = environment
        process.standardInput = FileHandle.nullDevice

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()

        let timeout = DispatchWorkItem {
            if process.isRunning {
                process.terminate()
            }
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + 60, execute: timeout)

        // Drain while the child runs, so large fetch output cannot fill the pipe.
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        timeout.cancel()

        let output = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .newlines)

        guard allowedStatuses.contains(process.terminationStatus), process.terminationReason == .exit else {
            let message = output.isEmpty ? String(localized: "Git could not finish. Check repository access and authentication, then retry.") : output

            // Avoid displaying embedded HTTPS credentials from Git diagnostics.
            let redacted = message.replacingOccurrences(of: #"https?://[^\s/@]+(?::[^\s/@]*)?@"#, with: "https://", options: .regularExpression)
            throw GitOperationError(errorDescription: redacted)
        }

        return output
    }
}
