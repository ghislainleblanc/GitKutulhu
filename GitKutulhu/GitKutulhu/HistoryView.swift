import SwiftUI

struct HistoryView: View {
    let repository: GitRepositorySnapshot?
    let revision: UUID
    let search: String
    @State private var store = HistoryStore()

    var body: some View {
        VSplitView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Repository history").font(.title2.weight(.semibold))
                    Spacer()
                    Label("All branches", systemImage: "arrow.triangle.branch").font(.caption).foregroundStyle(Palette.muted)
                }.padding(20)

                if repository == nil {
                    ContentUnavailableView("Open a repository", systemImage: "folder", description: Text("Choose a repository to browse its commit history."))
                } else {
                    HistoryCommitList(store: store, repository: repository, search: search)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .frame(minHeight: 290)

            if let commit = store.commits.first(where: { $0.id == store.selectedID }) {
                CommitDetail(commit: commit, files: store.files, isLoading: store.isLoadingFiles, error: store.fileError)
                    .frame(minHeight: 210, idealHeight: 270)
            }
        }
        .task(id: revision) { await store.reload(at: repository?.root) }
        .task(id: store.selectedID) {
            if let root = repository?.root, let commit = store.commits.first(where: { $0.id == store.selectedID }) {
                await store.loadFiles(at: root, commit: commit)
            }
        }
    }
}

private struct HistoryCommitList: View {
    @Bindable var store: HistoryStore
    let repository: GitRepositorySnapshot?
    let search: String

    var body: some View {
        let graphs = CommitGraph.layout(store.commits)
        let graphWidth = CGFloat(max(3, graphs.map(\.width).max() ?? 3) * 22 + 24)
        let rows = store.commits.enumerated().filter { _, commit in
            search.isEmpty || [commit.title, commit.message, commit.author, commit.email, commit.id, commit.references].contains { $0.localizedCaseInsensitiveContains(search) }
        }
        ScrollView([.horizontal, .vertical]) {
            LazyVStack(spacing: 0) {
                HStack {
                    Text("GRAPH").frame(width: graphWidth, alignment: .leading)
                    Text("COMMIT")
                    Spacer()
                    Text("AUTHOR").frame(width: 110, alignment: .leading)
                    Text("REVISION").frame(width: 75)
                }
                .font(.caption2.weight(.medium)).foregroundStyle(Palette.muted)
                .padding(.horizontal, 20).padding(.bottom, 12)
                Divider()
                ForEach(rows, id: \.element.id) { index, commit in
                    Button { store.selectedID = commit.id } label: {
                        CommitRow(commit: commit, graph: graphs[index], graphWidth: graphWidth, selected: store.selectedID == commit.id, showsGraph: search.isEmpty)
                    }.buttonStyle(.plain)
                }
                if store.isLoading {
                    ProgressView("Loading history…").padding(20)
                } else if let error = store.error {
                    Text(verbatim: error).foregroundStyle(.red).textSelection(.enabled).padding()
                    Button("Retry") {
                        Task { await store.reload(at: repository?.root) }
                    }.padding(.bottom)
                } else if store.commits.isEmpty {
                    ContentUnavailableView("No commits yet", systemImage: "clock", description: Text("Commits will appear here after the repository has history."))
                } else if rows.isEmpty {
                    ContentUnavailableView.search(text: search)
                }
                if store.hasMore, !search.isEmpty {
                    Text("Search covers loaded commits. Load older commits to search further.")
                        .font(.caption).foregroundStyle(Palette.muted).padding(.top, 12)
                }
                if store.hasMore, let root = repository?.root {
                    Button("Load older commits") { Task { await store.loadMore(at: root) } }
                        .disabled(store.isLoading).padding(16)
                }
            }.frame(minWidth: max(700, graphWidth + 550))
        }
    }
}

struct CommitRow: View {
    let commit: GitCommit
    let graph: CommitGraph
    let graphWidth: CGFloat
    let selected: Bool
    let showsGraph: Bool

    var body: some View {
        HStack(spacing: 0) {
            CommitGraphLane(graph: graph, showsConnections: showsGraph).frame(width: graphWidth, height: 62)
            VStack(alignment: .leading, spacing: 5) {
                Text(verbatim: commit.title).lineLimit(1).font(.callout.weight(.medium))
                HStack {
                    Text(commit.date, style: .relative)
                    if !commit.references.isEmpty {
                        Text(verbatim: commit.references).lineLimit(1).foregroundStyle(Palette.accent)
                    }
                }.font(.caption2).foregroundStyle(Palette.muted)
            }
            Spacer(minLength: 10)
            Text(verbatim: commit.author).font(.caption).foregroundStyle(Palette.muted).lineLimit(1).frame(width: 110, alignment: .leading)
            Text(verbatim: String(commit.id.prefix(7))).font(.system(.caption, design: .monospaced)).foregroundStyle(Palette.muted).frame(width: 75)
        }
        .padding(.horizontal, 20)
        .background(selected ? Palette.accent.opacity(0.08) : .clear)
        .overlay(alignment: .leading) {
            if selected {
                Rectangle().fill(Palette.accent).frame(width: 2)
            }
        }
        .contentShape(Rectangle())
    }
}

struct CommitGraphLane: View {
    let graph: CommitGraph
    let showsConnections: Bool

    var body: some View {
        Canvas { context, size in
            let colors = [Palette.accent, Palette.purple, Color.orange, Color.blue, Color.pink]
            let middle = size.height / 2
            if showsConnections {
                for (from, to) in graph.passing {
                    var path = Path()
                    path.move(to: CGPoint(x: CGFloat(from * 22 + 10), y: 0))
                    path.addCurve(to: CGPoint(x: CGFloat(to * 22 + 10), y: size.height), control1: CGPoint(x: CGFloat(from * 22 + 10), y: middle), control2: CGPoint(x: CGFloat(to * 22 + 10), y: middle))
                    context.stroke(path, with: .color(colors[from % colors.count].opacity(0.7)), lineWidth: 2)
                }
                for incoming in graph.incoming {
                    var path = Path()
                    path.move(to: CGPoint(x: CGFloat(incoming * 22 + 10), y: 0))
                    path.addLine(to: CGPoint(x: CGFloat(graph.lane * 22 + 10), y: middle))
                    context.stroke(path, with: .color(colors[graph.lane % colors.count]), lineWidth: 2)
                }
                for outgoing in graph.outgoing {
                    var path = Path()
                    path.move(to: CGPoint(x: CGFloat(graph.lane * 22 + 10), y: middle))
                    path.addCurve(to: CGPoint(x: CGFloat(outgoing * 22 + 10), y: size.height), control1: CGPoint(x: CGFloat(graph.lane * 22 + 10), y: middle + 15), control2: CGPoint(x: CGFloat(outgoing * 22 + 10), y: middle + 15))
                    context.stroke(path, with: .color(colors[outgoing % colors.count]), lineWidth: 2)
                }
            }
            let node = CGRect(x: CGFloat(graph.lane * 22 + 5), y: middle - 5, width: 10, height: 10)
            context.fill(Path(ellipseIn: node), with: .color(Palette.background))
            context.stroke(Path(ellipseIn: node), with: .color(colors[graph.lane % colors.count]), lineWidth: 2.5)
        }.accessibilityHidden(true)
    }
}

struct CommitDetail: View {
    let commit: GitCommit
    let files: [GitCommitFile]
    let isLoading: Bool
    let error: String?

    var body: some View {
        HSplitView {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("COMMIT DETAILS").font(.caption2.weight(.semibold)).foregroundStyle(Palette.muted)
                    Text(verbatim: commit.title).font(.title3.weight(.semibold))
                    Text(verbatim: "\(commit.author) <\(commit.email)>").font(.caption)
                    Text(commit.date, format: .dateTime.year().month().day().hour().minute()).font(.caption).foregroundStyle(Palette.muted)
                    Text(verbatim: commit.id).font(.system(.caption, design: .monospaced)).foregroundStyle(Palette.muted)
                    Text(verbatim: commit.message).font(.callout)
                    if !commit.references.isEmpty {
                        Text(verbatim: commit.references).font(.caption).foregroundStyle(Palette.accent)
                    }
                }.textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding(24)
            }.frame(minWidth: 320)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("CHANGED FILES").font(.caption2.weight(.semibold)).foregroundStyle(Palette.muted)
                    if commit.parents.count > 1 {
                        Text("Compared with the first parent").font(.caption2).foregroundStyle(Palette.muted)
                    }
                    if isLoading {
                        ProgressView("Loading changed files…")
                    } else if let error {
                        Text(verbatim: error).foregroundStyle(.red).textSelection(.enabled)
                    } else if files.isEmpty {
                        Text("No changed files").foregroundStyle(Palette.muted)
                    } else {
                        ForEach(files) { file in
                            HStack(alignment: .top) {
                                Image(systemName: "doc.text").foregroundStyle(Palette.muted)
                                Text(verbatim: file.id).font(.caption).textSelection(.enabled)
                                Spacer()
                                if let additions = file.additions, let deletions = file.deletions {
                                    ChangeCount(additions: additions, deletions: deletions)
                                } else {
                                    Text("Binary").font(.caption2).foregroundStyle(Palette.muted)
                                }
                            }
                        }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(24)
            }.frame(minWidth: 300, idealWidth: 380)
        }.background(Palette.panel)
    }
}
