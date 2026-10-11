# GitKutulhu

A lightweight, native SwiftUI Git client for macOS.

Open `GitKutulhu/GitKutulhu.xcodeproj` in Xcode and run the GitKutulhu scheme.
The project targets macOS 27 and Swift 6.

## Branch management

Choose **Open repository** and select an existing local clone of your GitHub
repository. The app reads the actual current branch, local branches, remote
tracking branches, and configured remotes. Linked worktrees are supported.
There is no automatic fetch when opening a repository: choose **Fetch** to
retrieve changes from all configured remotes and prune stale tracking branches.
Use **Refresh** after changing the repository in another app.

- Click a local branch to check it out. Click a remote branch to create and check
  out a local tracking branch. Git reports name collisions and worktree conflicts.
- **Branch** creates and checks out a local branch from the current HEAD. Git
  validates names and rejects duplicates.
- Right-click a local branch to rename or delete it. Renaming and deletion only
  affect local branches. Deletion requires confirmation and uses Git's safe
  deletion mode; the current branch cannot be deleted.
- Select a remote and choose **Push branch** to publish the current branch under
  the same name and set its upstream. An explicit refspec pushes only that branch.
  Non-fast-forward updates and GitHub branch protection failures are surfaced;
  the app never force-pushes.

Operations run off the main thread, controls are disabled while running, and
state is reloaded from disk after operations. Checkout does not discard or stash
local changes. Git errors appear in the interface; they are Git's own diagnostics
and may be in English. Interface strings include English, French, and Spanish.
Detached HEAD is displayed explicitly; push is unavailable until on a branch.
An empty repository needs an initial commit before creating branches.

### GitHub authentication and distribution

GitHub integration uses the real Git SSH/HTTPS transport, rather than the GitHub
REST API or an app-managed token. Configure credentials once outside the app:
use an SSH key available to your SSH agent/Keychain, or an HTTPS credential helper
(such as Git Credential Manager, the macOS Keychain helper, or GitHub CLI's Git
credential helper). Verify that fetching and pushing the clone works first.
The app uses `/usr/bin/git`, requires installed Apple command line tools, and
includes Homebrew locations when finding credential helpers. Git terminal
prompts are disabled and SSH uses batch mode. Missing credentials, unknown SSH
hosts, missing permissions, or expired credentials return an error; authenticate
or trust the host outside the app and retry. No credentials are stored by the app.
Network operations have a 60-second termination deadline.

App Sandbox is disabled in both build configurations so the Git subprocess can
write repository files and use existing Git configuration, credential helpers,
and SSH credentials. Hardened Runtime remains enabled. This build is intended
for direct macOS distribution; a Mac App Store sandbox design would require a
different credential and repository access strategy.

## Remaining UI previews

Commit history, staging, diffs, commit composition, conflict resolution, and AI
controls still use in-memory samples. A persistent banner identifies these
previews even while a real repository is connected. They never modify the
connected repository. Pull, merge, and rebase actions are not exposed yet.

UI components are grouped by workflow in `HistoryView.swift`, `ChangesView.swift`,
and `ConflictView.swift`. Real branch operations are in `GitBranchService.swift`
and observed UI state is in `BranchStore.swift`. Format touched Swift files using
the root `.swiftformat` configuration.

## Integration checks

The standalone Swift 6 integration test runs the same branch service used by the
app against disposable Git repositories and a bare remote. It covers creation,
checkout, rename, safe deletion, publishing/upstream setup, remote tracking,
fetch/prune, rejected pushes, invalid and duplicate names, detached HEAD, and
preservation of uncommitted files when checkout fails. It does not modify your
working repository or push to GitHub.

```sh
swiftc -swift-version 6 -module-cache-path /tmp/GitKutulhu-module-cache \
  GitKutulhu/GitKutulhu/GitBranchService.swift Tests/BranchIntegration.swift \
  -o /tmp/GitKutulhu-branch-tests
/tmp/GitKutulhu-branch-tests
```

For an additional live, read-only GitHub HTTPS fetch and tracking checkout check
against `octocat/Hello-World`, run:

```sh
GITKUTULHU_TEST_GITHUB=1 /tmp/GitKutulhu-branch-tests
```

Authenticated GitHub push and interactive UI behavior should also be checked
with your own clone and credentials before release.
