import SwiftUI

struct ConflictView: View {
    @Binding var workspace: DemoWorkspace

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Label(workspace.resolved ? "Conflict resolved" : "Resolve merge conflict", systemImage: workspace.resolved ? "checkmark.circle" : "arrow.triangle.merge")
                        .font(.title2.weight(.semibold))

                    Text("Demo merge · develop → feature/graph-view").font(.callout).foregroundStyle(Palette.muted)
                }

                Spacer()

                BranchBadge(name: "GraphLayout.swift", color: workspace.resolved ? Palette.accent : .orange)
            }

            HStack(alignment: .top, spacing: 16) {
                ConflictSide(title: "Current branch", branch: "feature/graph-view", code: "let laneWidth: CGFloat = 24\nlet rowHeight: CGFloat = 48") {
                    workspace.resolution = "let laneWidth: CGFloat = 24\nlet rowHeight: CGFloat = 48"
                    workspace.resolved = false
                }

                ConflictSide(title: "Incoming branch", branch: "develop", code: "let laneWidth: CGFloat = 28\nlet rowHeight: CGFloat = 52") {
                    workspace.resolution = "let laneWidth: CGFloat = 28\nlet rowHeight: CGFloat = 52"
                    workspace.resolved = false
                }
            }

            HStack {
                Text("Result").font(.headline)

                Spacer()

                Button {
                    workspace.resolution = "let laneWidth: CGFloat = 28\nlet rowHeight: CGFloat = 52"
                    workspace.resolved = false
                } label: { Label("Suggest resolution · Demo AI", systemImage: "sparkles") }
                    .buttonStyle(.bordered)
            }

            TextEditor(text: $workspace.resolution)
                .font(.system(.body, design: .monospaced)).scrollContentBackground(.hidden)
                .padding(12).background(Palette.panel, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.08)))
                .accessibilityLabel("Merged result")
                .onChange(of: workspace.resolution) { workspace.resolved = false }

            HStack {
                Text("Review the result before marking this conflict resolved.").font(.caption).foregroundStyle(Palette.muted)

                Spacer()

                Button { workspace.resolved = true } label: {
                    Label(workspace.resolved ? "Resolved" : "Mark resolved", systemImage: "checkmark")
                }.buttonStyle(.borderedProminent).disabled(workspace.resolution.isEmpty || workspace.resolved)
            }
        }.padding(24).frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ConflictSide: View {
    let title: LocalizedStringKey
    let branch: String
    let code: String
    let accept: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(title).font(.headline)

                Spacer()

                Button("Accept", action: accept).buttonStyle(.bordered)
            }

            BranchBadge(name: branch)

            Text(verbatim: code).font(.system(.callout, design: .monospaced)).textSelection(.enabled).padding(.vertical, 10)
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.panel, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.08)))
    }
}
