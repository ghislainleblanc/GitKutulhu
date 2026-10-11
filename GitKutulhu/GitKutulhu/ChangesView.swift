import SwiftUI

struct ChangesView: View {
    @Binding var workspace: DemoWorkspace
    let search: String
    @State private var split = true

    var body: some View {
        if workspace.committed {
            ContentUnavailableView("Demo commit created", systemImage: "checkmark.circle", description: Text("Your staged changes have been committed in this preview."))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            HSplitView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Working changes").font(.headline)

                        Spacer()

                        Button("Stage all") { workspace.staged = Set(DemoFile.samples.map(\.id)) }
                            .buttonStyle(.borderless).font(.caption)
                    }.padding(16)

                    Divider()

                    ScrollView {
                        VStack(spacing: 4) {
                            ForEach(DemoFile.samples.filter { search.isEmpty || $0.id.localizedCaseInsensitiveContains(search) }) { file in
                                FileChangeRow(file: file, selected: workspace.selectedFile == file.id, staged: workspace.staged.contains(file.id), select: { workspace.selectedFile = file.id }, toggle: {
                                    if !workspace.staged.insert(file.id).inserted {
                                        workspace.staged.remove(file.id)
                                    }
                                })
                            }
                        }.padding(8)
                    }

                    Divider()

                    CommitComposer(workspace: $workspace)
                }
                .frame(minWidth: 260, idealWidth: 285, maxWidth: 340)
                .background(Palette.panel)

                if let file = DemoFile.samples.first(where: { $0.id == workspace.selectedFile }) {
                    VStack(spacing: 0) {
                        HStack {
                            Image(systemName: "doc.text").foregroundStyle(Palette.muted)

                            Text(verbatim: file.id).font(.callout.weight(.medium))

                            ChangeCount(additions: file.additions, deletions: file.deletions)

                            Spacer()

                            Picker("Diff layout", selection: $split) {
                                Text("Split").tag(true)

                                Text("Unified").tag(false)
                            }.pickerStyle(.segmented).labelsHidden().frame(width: 130)
                        }.padding(16)

                        Divider()

                        DiffViewer(file: file, split: split)
                    }.frame(minWidth: 400)
                }
            }
        }
    }
}

struct FileChangeRow: View {
    let file: DemoFile
    let selected: Bool
    let staged: Bool
    let select: () -> Void
    let toggle: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: toggle) { Image(systemName: staged ? "checkmark.square.fill" : "square").foregroundStyle(staged ? Palette.accent : Palette.muted) }
                .buttonStyle(.plain).help(staged ? "Unstage file" : "Stage file").accessibilityLabel(staged ? "Unstage file" : "Stage file")

            Button(action: select) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(verbatim: file.id).font(.callout)

                    Text(verbatim: file.folder).font(.caption2).foregroundStyle(Palette.muted)
                }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(.plain)

            Text(verbatim: file.deletions == 0 ? "A" : "M").font(.caption2.bold()).foregroundStyle(Palette.accent)
        }
        .padding(10).background(selected ? Palette.accent.opacity(0.09) : .clear, in: RoundedRectangle(cornerRadius: 6))
    }
}

struct CommitComposer: View {
    @Binding var workspace: DemoWorkspace

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Commit").font(.headline)

                Spacer()

                Text(workspace.staged.count, format: .number).foregroundStyle(Palette.accent)

                Text("staged").foregroundStyle(Palette.muted)
            }.font(.caption)

            TextField("Commit summary…", text: $workspace.message, axis: .vertical)
                .textFieldStyle(.plain).lineLimit(3 ... 5).padding(10)
                .background(Palette.background, in: RoundedRectangle(cornerRadius: 6))

            Button {
                workspace.message = String(localized: "Add commit graph and refine branch navigation")
            } label: {
                Label("Generate message · Demo AI", systemImage: "sparkles")
            }.buttonStyle(.borderless).font(.caption).disabled(workspace.staged.isEmpty)

            Button { workspace.committed = true } label: {
                Label("Commit staged changes", systemImage: "checkmark").frame(maxWidth: .infinity).padding(.vertical, 5)
            }.buttonStyle(.borderedProminent)
                .disabled(workspace.staged.isEmpty || workspace.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Text("Preview only. No repository is modified.").font(.caption2).foregroundStyle(Palette.muted)
        }.padding(16)
    }
}

struct DiffViewer: View {
    let file: DemoFile
    let split: Bool

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(split ? "Before" : "Unified diff")

                    if split {
                        Spacer()

                        Text("After")

                        Spacer()
                    }
                }.font(.caption).foregroundStyle(Palette.muted).padding(12)

                Text(verbatim: "@@ -1,\(file.old.count) +1,\(file.new.count) @@")
                    .font(.system(.caption, design: .monospaced)).foregroundStyle(Palette.purple)
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading).background(Palette.purple.opacity(0.08))

                if split {
                    HStack(alignment: .top, spacing: 0) {
                        CodeLines(lines: file.old, kind: .removed).frame(minWidth: 340, maxWidth: .infinity)

                        Divider()

                        CodeLines(lines: file.new, kind: .added).frame(minWidth: 340, maxWidth: .infinity)
                    }
                } else {
                    CodeLines(lines: file.old, kind: .removed)

                    CodeLines(lines: file.new, kind: .added)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Palette.background)
    }
}

private struct CodeLines: View {
    let lines: [String]
    let kind: Kind

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                HStack(spacing: 12) {
                    Text((index + 1).formatted()).foregroundStyle(Palette.muted).frame(width: 28, alignment: .trailing)

                    Text(verbatim: kind == .added ? "+" : "−").foregroundStyle(kind == .added ? Palette.accent : .red)

                    Text(verbatim: line).foregroundStyle(Palette.text).fixedSize(horizontal: true, vertical: false)

                    Spacer(minLength: 12)
                }
                .font(.system(size: 12, design: .monospaced)).frame(height: 26).padding(.horizontal, 8)
                .background((kind == .added ? Palette.accent : Color.red).opacity(0.065))
            }
        }.textSelection(.enabled)
    }
}

private extension CodeLines {
    enum Kind { case added, removed }
}
