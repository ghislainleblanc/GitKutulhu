import AppKit
import SwiftUI

struct CloneRepositorySheet: View {
    @Environment(\.dismiss) private var dismiss
    let store: RepositoryWorkspaceStore
    @State private var source = ""
    @State private var folderName = ""
    @State private var parentFolder: URL?
    @FocusState private var sourceIsFocused: Bool

    private var destination: URL? {
        let name = folderName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let parentFolder, !name.isEmpty, name != ".", name != "..",
              !name.contains("/"), !name.contains(":"), !name.contains(where: \.isNewline)
        else { return nil }

        return parentFolder.appendingPathComponent(name, isDirectory: true)
    }

    private var canClone: Bool {
        !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && destination != nil && !store.isBusy
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Clone Repository", systemImage: "square.and.arrow.down")
                .font(.title2.weight(.semibold))

            Text("Clone with an HTTPS or SSH URL using your existing Git credentials.")
                .foregroundStyle(Palette.muted)

            VStack(alignment: .leading, spacing: 8) {
                Text("Repository URL")

                TextField("Repository URL", text: $source)
                    .labelsHidden()
                    .focused($sourceIsFocused)
                    .onChange(of: source) { oldValue, newValue in
                        if folderName.isEmpty || folderName == suggestedName(for: oldValue) {
                            folderName = suggestedName(for: newValue)
                        }
                    }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Destination folder")

                HStack {
                    if let parentFolder {
                        Text(verbatim: parentFolder.path)
                            .lineLimit(2)
                            .truncationMode(.middle)
                            .help(Text(verbatim: parentFolder.path))
                    } else {
                        Text("Choose where to save the repository.")
                            .foregroundStyle(Palette.muted)
                    }

                    Spacer()

                    Button("Choose folder…", action: chooseFolder)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Folder name")

                TextField("Folder name", text: $folderName)
                    .labelsHidden()
            }

            if let destination {
                Text(verbatim: destination.path)
                    .font(.caption)
                    .foregroundStyle(Palette.muted)
                    .textSelection(.enabled)
            }

            if let error = store.cloneError {
                ScrollView {
                    Text(verbatim: error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 100)
            }

            HStack {
                if store.isCloning {
                    ProgressView().controlSize(.small)

                    Text("Cloning repository…").foregroundStyle(Palette.muted)
                }

                Spacer()

                Button("Cancel", role: .cancel) { dismiss() }
                    .disabled(store.isCloning)
                    .keyboardShortcut(.cancelAction)

                Button("Clone Repository", action: clone)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canClone)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .textFieldStyle(.roundedBorder)
        .padding(24)
        .frame(width: 540)
        .tint(Palette.accent)
        .disabled(store.isCloning)
        .interactiveDismissDisabled(store.isCloning)
        .onAppear { sourceIsFocused = true }
    }
}

private extension CloneRepositorySheet {
    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = parentFolder
        panel.prompt = String(localized: "Choose folder")

        if panel.runModal() == .OK {
            parentFolder = panel.url
        }
    }

    func suggestedName(for source: String) -> String {
        let path = source.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = path.split(whereSeparator: { $0 == "/" || $0 == ":" }).last.map(String.init) ?? ""
        let withoutSuffix = name.hasSuffix(".git") ? String(name.dropLast(4)) : name

        return withoutSuffix == "." || withoutSuffix == ".." ? "" : withoutSuffix
    }

    func clone() {
        guard canClone, let destination else { return }

        Task {
            if await store.clone(source, to: destination) {
                dismiss()
            }
        }
    }
}
