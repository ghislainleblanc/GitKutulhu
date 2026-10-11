import SwiftUI

enum Palette {
    static let background = Color(red: 0.065, green: 0.080, blue: 0.10)
    static let panel = Color(red: 0.085, green: 0.105, blue: 0.13)
    static let raised = Color(red: 0.115, green: 0.14, blue: 0.17)
    static let accent = Color(red: 0.34, green: 0.85, blue: 0.73)
    static let text = Color(red: 0.88, green: 0.91, blue: 0.94)
    static let muted = Color(red: 0.55, green: 0.61, blue: 0.68)
    static let purple = Color(red: 0.65, green: 0.53, blue: 0.96)
}

struct BranchBadge: View {
    let name: String
    var color = Palette.accent

    var body: some View {
        Label { Text(verbatim: name) } icon: { Image(systemName: "arrow.triangle.branch") }
            .font(.system(size: 10, weight: .medium)).foregroundStyle(color)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
    }
}

struct ChangeCount: View {
    let additions: Int
    let deletions: Int

    var body: some View {
        HStack(spacing: 8) {
            Text("+\(additions.formatted())").foregroundStyle(Palette.accent)
            Text("−\(deletions.formatted())").foregroundStyle(.red.opacity(0.9))
        }.font(.system(.caption2, design: .monospaced))
    }
}
