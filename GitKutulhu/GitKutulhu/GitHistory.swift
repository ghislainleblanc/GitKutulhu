import Foundation
import Observation

nonisolated struct GitCommit: Identifiable, Sendable {
    let id: String
    let parents: [String]
    let author: String
    let email: String
    let date: Date
    let title: String
    let message: String
    let references: String
}

nonisolated struct GitCommitFile: Identifiable, Sendable {
    let id: String
    let additions: Int?
    let deletions: Int?
}

nonisolated struct CommitGraph: Sendable {
    let lane: Int
    let incoming: [Int]
    let outgoing: [Int]
    let passing: [(Int, Int)]
    let width: Int

    static func layout(_ commits: [GitCommit]) -> [CommitGraph] {
        var lanes: [String] = []
        return commits.map { commit in
            let hasIncoming = lanes.contains(commit.id)
            if !hasIncoming {
                lanes.append(commit.id)
            }
            let before = lanes
            let lane = lanes.firstIndex(of: commit.id)!
            lanes.remove(at: lane)
            for parent in commit.parents.reversed() where !lanes.contains(parent) {
                lanes.insert(parent, at: min(lane, lanes.count))
            }
            let passing = before.enumerated().compactMap { index, id -> (Int, Int)? in
                guard id != commit.id, let next = lanes.firstIndex(of: id) else { return nil }
                return (index, next)
            }
            return CommitGraph(lane: lane, incoming: hasIncoming ? [lane] : [], outgoing: commit.parents.compactMap { lanes.firstIndex(of: $0) }, passing: passing, width: max(before.count, lanes.count))
        }
    }
}

@MainActor
@Observable
final class HistoryStore {
    private(set) var commits: [GitCommit] = []
    private(set) var files: [GitCommitFile] = []
    private(set) var isLoading = false
    private(set) var isLoadingFiles = false
    private(set) var hasMore = false
    var selectedID: String?
    var error: String?
    var fileError: String?
    private let service = GitBranchService()
    private var generation = UUID()

    func reload(at root: URL?) async {
        let generation = UUID()
        self.generation = generation
        commits = []
        files = []
        selectedID = nil
        error = nil
        fileError = nil
        hasMore = false
        isLoadingFiles = false
        isLoading = false
        guard let root else { return }
        await load(at: root, generation: generation)
    }

    func loadMore(at root: URL) async {
        guard !isLoading, hasMore else { return }
        await load(at: root, generation: generation)
    }

    func loadFiles(at root: URL, commit: GitCommit) async {
        let generation = generation
        files = []
        fileError = nil
        isLoadingFiles = true
        do {
            let result = try await service.changedFiles(for: commit, at: root)
            guard !Task.isCancelled, self.generation == generation, selectedID == commit.id else { return }
            files = result
        } catch {
            guard !Task.isCancelled, self.generation == generation, selectedID == commit.id else { return }
            fileError = error.localizedDescription
        }
        isLoadingFiles = false
    }
}

private extension HistoryStore {
    func load(at root: URL, generation: UUID) async {
        isLoading = true
        error = nil
        do {
            let page = try await service.history(at: root, skip: commits.count)
            guard !Task.isCancelled, self.generation == generation else { return }
            hasMore = page.count > 200
            commits.append(contentsOf: page.prefix(200))
            if selectedID == nil {
                selectedID = commits.first?.id
            }
        } catch {
            guard !Task.isCancelled, self.generation == generation else { return }
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}
