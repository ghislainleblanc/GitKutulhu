import SwiftUI

struct ChangesView: View {
    let branches: BranchStore
    @Bindable var store: ChangesStore
    let search: String
    @State private var split = true

    var body: some View {
        Group {
            if branches.repository == nil {
                ContentUnavailableView("No repository", systemImage: "folder", description: Text("Open a repository to view and commit changes."))
            } else {
                HSplitView {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text("Working changes").font(.headline)

                            Spacer()

                            Button("Stage all") { branches.stage(nil) }
                                .buttonStyle(.borderless).font(.caption)
                                .disabled(branches.isBusy || store.isLoading || store.error != nil || store.hasConflicts || !store.files.contains(where: { !$0.staged }))
                        }.padding(16)

                        Divider()

                        if let error = store.error {
                            Text(verbatim: error).foregroundStyle(.red).textSelection(.enabled).padding()
                        }

                        if store.hasConflicts {
                            Text("Resolve conflicts in your editor, then stage the resolved files. The Conflicts tab is a preview.")
                                .font(.caption).foregroundStyle(.orange).padding()
                        }

                        if store.files.isEmpty, !store.isLoading, store.error == nil {
                            ContentUnavailableView("Working tree clean", systemImage: "checkmark.circle", description: Text("No changes to stage or commit."))
                        }

                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 4) {
                                ForEach([false, true], id: \.self) { staged in
                                    Text(staged ? "Staged changes" : "Unstaged changes")
                                        .font(.caption.weight(.semibold)).foregroundStyle(Palette.muted).padding(8)

                                    ForEach(store.files.filter { $0.staged == staged && (search.isEmpty || $0.path.localizedCaseInsensitiveContains(search)) }) { file in
                                        FileChangeRow(file: file, selected: store.selectedID == file.id, disabled: branches.isBusy || store.isLoading || store.error != nil, select: { store.selectedID = file.id }, toggle: {
                                            if file.staged {
                                                branches.unstage(file)
                                            } else {
                                                branches.stage(file)
                                            }
                                        })
                                    }
                                }
                            }.padding(8)
                        }

                        Divider()

                        CommitComposer(store: store, branches: branches)
                    }
                    .frame(minWidth: 260, idealWidth: 300, maxWidth: 360)
                    .background(Palette.panel)

                    VStack(spacing: 0) {
                        if let file = store.selectedFile {
                            HStack {
                                Image(systemName: "doc.text").foregroundStyle(Palette.muted)

                                VStack(alignment: .leading) {
                                    Text(verbatim: file.path).font(.callout.weight(.medium))

                                    Text(file.staged ? "Staged changes" : "Unstaged changes").font(.caption).foregroundStyle(Palette.muted)
                                }

                                Spacer()

                                if store.isLoadingDiff {
                                    ProgressView().controlSize(.small)
                                }

                                Picker("Diff layout", selection: $split) {
                                    Text("Split").tag(true)

                                    Text("Unified").tag(false)
                                }.pickerStyle(.segmented).labelsHidden().frame(width: 130)
                            }.padding(16)

                            Divider()

                            if let error = store.diffError {
                                Text(verbatim: error).foregroundStyle(.red).textSelection(.enabled).padding()
                            } else if store.patch.isEmpty {
                                ContentUnavailableView("No text diff", systemImage: "doc", description: Text("This change has no text patch to display."))
                            } else {
                                DiffViewer(patch: store.patch, split: split)
                            }
                        } else {
                            ContentUnavailableView("Select a changed file", systemImage: "doc.text.magnifyingglass")
                        }
                    }.frame(minWidth: 400, maxHeight: .infinity)
                }
            }
        }
        .disabled(branches.repository?.root != store.repositoryRoot)
        .task(id: branches.revision) {
            repeat {
                if !branches.isBusy {
                    await store.reload(at: branches.repository?.root)
                }

                do {
                    try await Task.sleep(for: .seconds(3))
                } catch {
                    return
                }
            } while !Task.isCancelled
        }
        .task(id: store.selectedID) { await store.loadDiff() }
    }
}

struct FileChangeRow: View {
    let file: GitWorkingFile
    let selected: Bool
    let disabled: Bool
    let select: () -> Void
    let toggle: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: toggle) { Image(systemName: file.staged ? "checkmark.square.fill" : "square").foregroundStyle(file.staged ? Palette.accent : Palette.muted) }
                .buttonStyle(.plain).disabled(disabled)
                .help(file.staged ? "Unstage file" : "Stage file").accessibilityLabel(file.staged ? "Unstage file" : "Stage file")

            Button(action: select) {
                Text(verbatim: file.path).font(.callout).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(.plain)

            Text(verbatim: file.status).font(.caption2.bold()).foregroundStyle(file.conflicted ? .orange : Palette.accent)
        }
        .padding(10).background(selected ? Palette.accent.opacity(0.09) : .clear, in: RoundedRectangle(cornerRadius: 6))
    }
}

struct CommitComposer: View {
    @Bindable var store: ChangesStore
    let branches: BranchStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Commit").font(.headline)

                Spacer()

                Text(store.stagedCount, format: .number).foregroundStyle(Palette.accent)

                Text("staged").foregroundStyle(Palette.muted)
            }.font(.caption)

            TextField("Commit summary…", text: $store.message, axis: .vertical)
                .textFieldStyle(.plain).lineLimit(3 ... 5).padding(10)
                .background(Palette.background, in: RoundedRectangle(cornerRadius: 6))
                .disabled(branches.isBusy)

            Button {
                let message = store.message

                Task {
                    if await branches.commit(message) {
                        store.message = ""
                        await store.reload(at: branches.repository?.root)
                    }
                }
            } label: {
                Label("Commit staged changes", systemImage: "checkmark").frame(maxWidth: .infinity).padding(.vertical, 5)
            }.buttonStyle(.borderedProminent)
                .disabled(branches.isBusy || store.isLoading || store.error != nil || store.hasConflicts || store.stagedCount == 0 || store.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Text("Commits include staged changes only and remain local until pushed.").font(.caption2).foregroundStyle(Palette.muted)
        }.padding(16)
    }
}

struct DiffViewer: View {
    let patch: String
    let split: Bool

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            LazyVStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(split ? "Before" : "Unified diff")

                    if split {
                        Spacer()

                        Text("After")

                        Spacer()
                    }
                }.font(.caption).foregroundStyle(Palette.muted).padding(12)

                if split {
                    let rows = GitDiffRow.split(patch)

                    HStack(alignment: .top, spacing: 0) {
                        DiffColumn(rows: rows, before: true)

                        Divider()

                        DiffColumn(rows: rows, before: false)
                    }
                } else {
                    ForEach(Array(patch.components(separatedBy: "\n").enumerated()), id: \.offset) { _, line in
                        DiffCell(text: line, number: nil, color: line.hasPrefix("+") ? Palette.accent : line.hasPrefix("-") ? .red : .clear)
                    }
                }
            }.textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Palette.background)
    }
}

private struct DiffColumn: View {
    let rows: [GitDiffRow]
    let before: Bool

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                DiffCell(text: before ? row.before : row.after,
                         number: before ? row.oldLine : row.newLine,
                         color: row.changed ? (before ? .red : Palette.accent) : .clear)
            }
        }.frame(minWidth: 340, maxWidth: .infinity)
    }
}

private struct DiffCell: View {
    let text: String?
    let number: Int?
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Text(verbatim: number?.formatted() ?? "").foregroundStyle(Palette.muted).frame(width: 45, alignment: .trailing)

            Text(verbatim: text ?? "").fixedSize(horizontal: true, vertical: false)

            Spacer(minLength: 12)
        }
        .font(.system(size: 12, design: .monospaced)).frame(minWidth: 340, maxWidth: .infinity, alignment: .leading).frame(height: 26).padding(.horizontal, 8)
        .background(text == nil ? .clear : color.opacity(0.08))
    }
}
