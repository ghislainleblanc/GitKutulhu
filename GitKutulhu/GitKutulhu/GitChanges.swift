import Foundation
import Observation

nonisolated struct GitWorkingFile: Identifiable, Sendable, Equatable {
    let path: String
    let staged: Bool
    let status: String
    let conflicted: Bool

    var id: String {
        (staged ? "index:" : "worktree:") + path
    }
}

nonisolated struct GitDiffRow: Sendable {
    let before: String?
    let after: String?
    let oldLine: Int?
    let newLine: Int?
    let changed: Bool

    static func split(_ patch: String) -> [GitDiffRow] {
        var rows: [GitDiffRow] = []
        var removed: [(String, Int)] = []
        var added: [(String, Int)] = []
        var oldLine = 0
        var newLine = 0
        var inHunk = false

        func flush() {
            for index in 0 ..< max(removed.count, added.count) {
                rows.append(GitDiffRow(before: index < removed.count ? removed[index].0 : nil,
                                       after: index < added.count ? added[index].0 : nil,
                                       oldLine: index < removed.count ? removed[index].1 : nil,
                                       newLine: index < added.count ? added[index].1 : nil, changed: true))
            }

            removed = []
            added = []
        }

        for line in patch.components(separatedBy: "\n") {
            if line.hasPrefix("@@ ") {
                flush()

                let fields = line.split(separator: " ")
                oldLine = Int(fields[1].dropFirst().split(separator: ",")[0]) ?? 0
                newLine = Int(fields[2].dropFirst().split(separator: ",")[0]) ?? 0
                inHunk = true
                rows.append(GitDiffRow(before: line, after: line, oldLine: nil, newLine: nil, changed: false))
            } else if inHunk, line.hasPrefix("-") {
                removed.append((String(line.dropFirst()), oldLine))
                oldLine += 1
            } else if inHunk, line.hasPrefix("+") {
                added.append((String(line.dropFirst()), newLine))
                newLine += 1
            } else if inHunk, line.hasPrefix(" ") {
                flush()
                rows.append(GitDiffRow(before: String(line.dropFirst()), after: String(line.dropFirst()), oldLine: oldLine, newLine: newLine, changed: false))
                oldLine += 1
                newLine += 1
            } else {
                flush()
                rows.append(GitDiffRow(before: line, after: line, oldLine: nil, newLine: nil, changed: false))
            }
        }

        flush()

        return rows
    }
}

@MainActor
@Observable
final class ChangesStore {
    private(set) var files: [GitWorkingFile] = []
    private(set) var patch = ""
    private(set) var isLoading = false
    private(set) var isLoadingDiff = false
    private(set) var error: String?
    private(set) var diffError: String?
    var selectedID: String?
    var message = ""
    private var root: URL?
    private var request = UUID()
    private var diffRequest = UUID()
    private var displayedID: String?
    private var hasLoaded = false
    private let service = GitBranchService()

    var repositoryRoot: URL? {
        root
    }

    var selectedFile: GitWorkingFile? {
        files.first { $0.id == selectedID }
    }

    var stagedCount: Int {
        files.filter(\.staged).count
    }

    var hasConflicts: Bool {
        files.contains(where: \.conflicted)
    }

    func reload(at root: URL?) async {
        let request = UUID()
        self.request = request

        if self.root != root {
            self.root = root
            files = []
            patch = ""
            selectedID = nil
            message = ""
            diffError = nil
            diffRequest = UUID()
            isLoadingDiff = false
            hasLoaded = false
        }

        if error != nil {
            error = nil
        }

        if !hasLoaded, !isLoading {
            isLoading = true
        }

        guard let root else {
            if isLoading {
                isLoading = false
            }

            return
        }

        do {
            let files = try await service.workingChanges(at: root)

            guard self.request == request, !Task.isCancelled else { return }

            if self.files != files {
                self.files = files
            }

            if !files.contains(where: { $0.id == selectedID }) {
                let nextSelectedID = files.first?.id

                if selectedID != nextSelectedID {
                    selectedID = nextSelectedID
                }
            }
        } catch {
            guard self.request == request, !Task.isCancelled else { return }

            let description = error.localizedDescription

            if self.error != description {
                self.error = description
            }
        }

        hasLoaded = true

        if isLoading {
            isLoading = false
        }

        await loadDiff()
    }

    func loadDiff() async {
        let request = UUID()
        diffRequest = request
        if diffError != nil {
            diffError = nil
        }

        guard let root, let file = selectedFile else {
            if !patch.isEmpty {
                patch = ""
            }

            if isLoadingDiff {
                isLoadingDiff = false
            }

            return
        }

        let isChangingFile = displayedID != file.id

        if isChangingFile {
            patch = ""
        }

        if isChangingFile {
            displayedID = file.id
            isLoadingDiff = true
        }

        do {
            let patch = try await service.workingDiff(for: file, at: root)

            guard diffRequest == request, !Task.isCancelled, selectedID == file.id else { return }

            if self.patch != patch {
                self.patch = patch
            }
        } catch {
            guard diffRequest == request, !Task.isCancelled, selectedID == file.id else { return }

            if !patch.isEmpty {
                patch = ""
            }

            let description = error.localizedDescription

            if diffError != description {
                diffError = description
            }
        }

        if isLoadingDiff {
            isLoadingDiff = false
        }
    }
}
