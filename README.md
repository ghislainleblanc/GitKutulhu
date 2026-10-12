# GitKutulhu

A lightweight, native SwiftUI Git client for macOS.

Open `GitKutulhu/GitKutulhu.xcodeproj` in Xcode and run the GitKutulhu scheme.
The project targets macOS 27 and Swift 6.

## Open repositories

Choose **Open repository** (⌘O) to open one or more local clones. Each repository
has a tab; click a tab to switch, and hover over it to see its full path. Opening
an already open repository, a subfolder, or a symbolic link selects the existing
tab. Linked worktrees have their own tabs.

Choose **Clone Repository** beside **Open repository** to clone an HTTPS or SSH
URL. Choose a destination folder and a new folder name (suggested from the URL),
then choose **Clone Repository**. Git runs in the background with a progress
indicator, using the authentication described below. The completed clone opens
in a new tab and is saved with the workspace. Existing destination folders are
rejected, including empty folders. Errors stay in the dialog so you can correct
the URL or destination and retry.

The app automatically saves the open repository list and selected tab in local
preferences and restores them at launch. Closing a tab removes it from the saved
list without changing repository files. Unavailable repositories stay listed;
reconnect their drive or restore their folder and choose **Retry**, or close their
tab. Restoration only reads local Git state and never fetches automatically.

Each repository keeps its own commit draft, selected remote, view, and filter
while the app is running. Drafts are not saved across launches. Closing a tab
with a draft asks before discarding it; working files and staged changes remain
on disk.

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

## Repository history

History reads commits reachable from local branches, remote tracking branches,
tags, and HEAD. The graph follows actual parent links, including merges. Select
any commit to see its full message, author, date, revision, and changed files with
line counts or a binary indicator. Merge summaries compare against the first
parent. Renames appear as an added and deleted path.

History loads 200 commits at a time; choose **Load older commits** to continue.
Search filters loaded commits by message, author, email, revision, and reference.
Graph connections are hidden while filtering to avoid implying adjacency between
unrelated search results. History reloads after branch operations and **Refresh**.
No repository content is modified by browsing history.

## Working changes and commits

Changes reads the connected repository's index and working tree, including
untracked files and deletions. Ignored files are omitted. Files with both staged
and unstaged edits appear in both groups. Search filters their full paths.
Select an entry to view its actual staged or unstaged patch in split or unified
layout. Split diffs preserve context and hunk line numbers. Binary changes and
file metadata appear in Git's patch output; renames appear as deleted/added paths.

- **Stage file** stages that file's current contents or deletion. **Stage all**
  stages all non-ignored changes in the repository, including filtered-out files.
- **Unstage file** removes the file from the index without changing its working
  copy. This also works before the initial commit.
- Enter a summary and choose **Commit staged changes** to create a local commit
  containing only the index. Unstaged edits are preserved. Git's configured
  identity, hooks, and signing settings apply; failures show Git's diagnostics
  and retain the draft. Successful commits clear the draft and refresh state.
  Choose **Push branch** separately to publish commits.

Changes refreshes after app operations, on **Refresh**, and every three seconds
while visible to pick up external edits. Commit drafts survive switching tabs
and switching repositories. Each repository has a separate draft. Git operations
share the busy state with branch controls to prevent overlapping app mutations
in the same repository.

Unresolved files are marked `U`. Resolve them in an external editor and stage
each resolved file; commits and **Stage all** are disabled while conflicts remain.
Pull, merge, and rebase actions are not exposed yet.

UI components are grouped by workflow in `HistoryView.swift` and `ChangesView.swift`.
Git operations are in `GitBranchService.swift`, observed
repository state is in `BranchStore.swift`, and changes/diff state is in
`GitChanges.swift`. Format touched Swift files using the root `.swiftformat`.

## Integration checks

The standalone Swift 6 integration test runs the same branch service used by the
app against disposable Git repositories and a bare remote. It covers creation,
checkout, rename, safe deletion, publishing/upstream setup, remote tracking,
fetch/prune, rejected pushes, invalid and duplicate names, detached HEAD, and
preservation of uncommitted files when checkout fails. It does not modify your
working repository or push to GitHub.

```sh
swiftc -swift-version 6 -module-cache-path /tmp/GitKutulhu-module-cache \
  GitKutulhu/GitKutulhu/GitBranchService.swift GitKutulhu/GitKutulhu/GitHistory.swift \
  GitKutulhu/GitKutulhu/GitChanges.swift \
  Tests/BranchIntegration.swift \
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

History integration checks cover empty repositories, full messages, merge and
root summaries, binary files, Unicode/tab/newline paths, detached HEAD, remote
references, graph continuity, pagination, and store reset/error states:

```sh
swiftc -swift-version 6 -module-cache-path /tmp/GitKutulhu-module-cache \
  GitKutulhu/GitKutulhu/GitBranchService.swift GitKutulhu/GitKutulhu/GitHistory.swift \
  GitKutulhu/GitKutulhu/GitChanges.swift \
  Tests/HistoryIntegration.swift -o /tmp/GitKutulhu-history-tests
/tmp/GitKutulhu-history-tests
```

Changes integration checks cover initial commits, ignored files, literal
Unicode/tab/newline/glob-like paths, staged and unstaged patches, split hunk
alignment, partial staging, unstaging without changing working files, binary
files, deletions, renames, hook failures, conflict status, and store reset/errors:

```sh
swiftc -swift-version 6 -module-cache-path /tmp/GitKutulhu-module-cache \
  GitKutulhu/GitKutulhu/GitBranchService.swift GitKutulhu/GitKutulhu/GitHistory.swift \
  GitKutulhu/GitKutulhu/GitChanges.swift Tests/ChangesIntegration.swift \
  -o /tmp/GitKutulhu-changes-tests
/tmp/GitKutulhu-changes-tests
```

Repository workspace checks cover opening multiple repositories, separate drafts,
duplicate subfolders and symlinks, linked worktrees, missing-folder recovery,
closing tabs, and restoration from saved preferences in a separate process.
They also cover cloning populated and empty remotes, opening and restoring the
cloned tab, preserving existing destinations and symlinks, and retrying failures:

```sh
swiftc -swift-version 6 -module-cache-path /tmp/GitKutulhu-workspace-test-cache \
  GitKutulhu/GitKutulhu/GitBranchService.swift GitKutulhu/GitKutulhu/GitHistory.swift \
  GitKutulhu/GitKutulhu/GitChanges.swift GitKutulhu/GitKutulhu/BranchStore.swift \
  GitKutulhu/GitKutulhu/WorkspaceModels.swift \
  GitKutulhu/GitKutulhu/RepositoryWorkspaceStore.swift \
  Tests/RepositoryWorkspaceIntegration.swift -o /tmp/GitKutulhu-workspace-tests
/tmp/GitKutulhu-workspace-tests
```
