import SwiftUI

struct HistoryView: View {
    let search: String
    @State private var selected = DemoCommit.samples[0].id

    var body: some View {
        VSplitView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Repository history").font(.title2.weight(.semibold))

                    Spacer()

                    Label("All branches", systemImage: "arrow.triangle.branch").font(.caption).foregroundStyle(Palette.muted)
                }
                .padding(20)

                HStack {
                    Text("GRAPH").frame(width: 90, alignment: .leading)

                    Text("COMMIT")

                    Spacer()

                    Text("AUTHOR").frame(width: 110, alignment: .leading)

                    Text("REVISION").frame(width: 75)
                }
                .font(.caption2.weight(.medium)).foregroundStyle(Palette.muted).padding(.horizontal, 20).padding(.bottom, 12)

                Divider()

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(DemoCommit.samples.filter { search.isEmpty || String(localized: $0.title).localizedCaseInsensitiveContains(search) || $0.id.contains(search) }) { commit in
                            Button { selected = commit.id } label: {
                                CommitRow(commit: commit, selected: selected == commit.id)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .frame(minHeight: 290)

            if let commit = DemoCommit.samples.first(where: { $0.id == selected }) {
                CommitDetail(commit: commit).frame(minHeight: 210, idealHeight: 240)
            }
        }
    }
}

struct CommitRow: View {
    let commit: DemoCommit
    let selected: Bool

    var body: some View {
        HStack(spacing: 0) {
            CommitGraphLane(lane: commit.lane).frame(width: 90, height: 52)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    if let branch = commit.branch {
                        BranchBadge(name: branch, color: commit.lane == 0 ? Palette.accent : Palette.purple)
                    }

                    Text(commit.title).lineLimit(1).font(.callout.weight(.medium))
                }

                Text(Date.now.addingTimeInterval(Double(-commit.age * 60)), style: .relative)
                    .font(.caption2).foregroundStyle(Palette.muted)
            }

            Spacer(minLength: 10)

            Text(commit.author == "You" ? String(localized: "You") : commit.author).font(.caption).foregroundStyle(Palette.muted).frame(width: 110, alignment: .leading)

            Text(verbatim: commit.id).font(.system(.caption, design: .monospaced)).foregroundStyle(Palette.muted).frame(width: 75)
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
    let lane: Int

    var body: some View {
        Canvas { context, size in
            let colors = [Palette.accent, Palette.purple, Color.orange]

            for index in 0 ..< 3 {
                let x = CGFloat(index * 22 + 10)
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))

                context.stroke(path, with: .color(colors[index].opacity(index == lane ? 0.8 : 0.25)), lineWidth: 2)
            }

            if lane == 2 {
                var path = Path()
                path.move(to: CGPoint(x: 32, y: 0))
                path.addCurve(to: CGPoint(x: 54, y: 26), control1: CGPoint(x: 32, y: 18), control2: CGPoint(x: 54, y: 8))

                context.stroke(path, with: .color(Palette.purple.opacity(0.6)), lineWidth: 2)
            }

            let node = CGRect(x: CGFloat(lane * 22 + 5), y: size.height / 2 - 5, width: 10, height: 10)

            context.fill(Path(ellipseIn: node), with: .color(Palette.background))
            context.stroke(Path(ellipseIn: node), with: .color(colors[lane]), lineWidth: 2.5)
        }
        .accessibilityHidden(true)
    }
}

struct CommitDetail: View {
    let commit: DemoCommit

    var body: some View {
        HStack(alignment: .top, spacing: 30) {
            VStack(alignment: .leading, spacing: 14) {
                Text("COMMIT DETAILS").font(.caption2.weight(.semibold)).foregroundStyle(Palette.muted)

                Text(commit.title).font(.title3.weight(.semibold))

                HStack {
                    Text(verbatim: String(commit.author.prefix(1))).font(.caption.bold()).frame(width: 28, height: 28).background(Palette.purple.opacity(0.2), in: Circle())

                    Text(commit.author == "You" ? String(localized: "You") : commit.author)

                    Text(verbatim: "·  \(commit.id)").foregroundStyle(Palette.muted)
                }.font(.caption)

                Text("Sample commit from the demo repository.").font(.callout).foregroundStyle(Palette.muted)

                if let branch = commit.branch {
                    BranchBadge(name: branch)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            VStack(alignment: .leading, spacing: 14) {
                Text("CHANGED FILES").font(.caption2.weight(.semibold)).foregroundStyle(Palette.muted)

                ForEach(DemoFile.samples) { file in
                    HStack {
                        Image(systemName: "doc.text").foregroundStyle(Palette.muted)

                        Text(verbatim: file.id).font(.caption)

                        Spacer()

                        ChangeCount(additions: file.additions, deletions: file.deletions)
                    }
                }

                Text("Illustrative file summary").font(.caption2).foregroundStyle(Palette.muted)
            }
            .frame(width: 310)
        }
        .padding(24).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).background(Palette.panel)
    }
}
