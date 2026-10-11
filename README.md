# GitKutulhu

A lightweight, native SwiftUI Git client interface for macOS.

Open `GitKutulhu/GitKutulhu.xcodeproj` in Xcode and run the GitKutulhu scheme.
The project currently targets macOS 27 and Swift 6.

## UI preview

- Repository sidebar with branch selection and branch creation.
- Filterable commit history with branch lanes and commit details.
- Working changes with staging, split/unified diffs, and a commit composer.
- Conflict editor with current/incoming versions, an editable result, and resolution state.
- Demo AI controls for commit messages and conflict suggestions.
- English, French, and Spanish interface strings.

All content is sample data held in memory. Git operations and AI services are not
connected. Preview actions never modify a repository; restarting the app resets
the demo. Fetch, pull, push, merge, and rebase controls explain this limitation.

UI components are grouped by workflow in `HistoryView.swift`, `ChangesView.swift`,
and `ConflictView.swift`. Shared sample data lives in `WorkspaceModels.swift`.
Format touched Swift files using the root `.swiftformat` configuration.
