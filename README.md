# zsh-functions

A collection of powerful zsh utilities to streamline your git/GitHub workflow. These functions provide interactive, user-friendly interfaces for common git operations with smart defaults and helpful prompts.

## Table of Contents

- [Installation](#installation)
- [Configuration](#configuration)
- [Commands](#commands)
  - [branch](#branch)
  - [create](#create)
  - [switch](#switch)
  - [commit](#commit)
  - [status](#status)
  - [pr](#pr)
  - [update](#update)
  - [stash](#stash)
  - [stashes](#stashes)
  - [unstash](#unstash)
  - [cleanstash](#cleanstash)
- [Requirements](#requirements)

### Workflow Example

A possible workflow with some of the commands

```bash
# Use the interactive branch menu
$ branch
# Select "Create" from menu

# Or use create directly
$ create PROJ-123 add user authentication
Updating 'main' from origin...
✓ 'main' is up to date.
✓ Successfully created and switched to branch: feature/PROJ-123-add-user-authentication (from main)

# Make your changes...

# Review and selectively stage changes
$ status
# Press Enter to toggle staging, ESC to exit

# Commit staged changes
$ commit implement login form

# Or commit and push everything
$ commit -p add validation

# Keep branch up to date with main
$ update

# Use the branch menu to switch
$ branch
# Select "Switch" from menu

# Or use switch directly
$ switch
# Use arrow keys to select, preview shows commit history

# Open PR when ready
$ pr
```

---

## Installation

Make sure [`fzf`](https://github.com/junegunn/fzf) is installed on your system

Clone the repository

```bash
mkdir -p ~/.config/zsh && git clone git@github.com:jaggli/zsh-functions.git ~/.config/zsh/zsh-functions
```

Add this to your `~/.zshrc`:

```bash
# Optional configuration for zsh functions
export ZSH_FUNCTIONS_FEATURE_BRANCH_PREFIX="feature/"  # Prefix for newly created feature branches
export ZSH_FUNCTIONS_GIT_MERGE_COMMAND="fork"         # Executable to resolve merge conflicts

# Include all custom zsh functions
for f in ~/.config/zsh/zsh-functions/*.zsh; do
  source "$f"
done
```

Reload your shell:

```bash
source ~/.zshrc
```

## Configuration

All configuration is done through environment variables that should be set in your `~/.zshrc` before sourcing the functions:

| Variable                              | Default      | Description                                                                       |
| ------------------------------------- | ------------ | --------------------------------------------------------------------------------- |
| `ZSH_FUNCTIONS_FEATURE_BRANCH_PREFIX` | `"feature/"` | Prefix for newly created feature branches                                         |
| `ZSH_FUNCTIONS_GIT_MERGE_COMMAND`     | `""`         | Executable to open when merge conflicts occur (e.g., `fork`, `code`, `gitkraken`) |

### Example Configuration

```bash
# In ~/.zshrc

# Use a different branch prefix
export ZSH_FUNCTIONS_FEATURE_BRANCH_PREFIX="feat/"

# Open VS Code for merge conflicts
export ZSH_FUNCTIONS_GIT_MERGE_COMMAND="code"

# Or use GitKraken
export ZSH_FUNCTIONS_GIT_MERGE_COMMAND="gitkraken"
```

## Commands

### branch

Interactive menu to manage git branches with quick access to all branch operations.

**Usage:**

```bash
branch
```

**Options:**

- `-h, --help` - Show help message

**Features:**

- Interactive action selection menu
- Quick access to create, switch, and update operations
- Powered by fzf for intuitive selection
- Case-insensitive filtering
- Auto-installs fzf if missing (with permission)

**Examples:**

```bash
$ branch
Branch action >
> 🌿 Create - Create a new feature branch
  🔀 Switch - Switch to another branch
  ⬆️  Update - Update current branch with main/master
  ✖ Abort

# Navigate with ↑/↓ or j/k, press Enter to select
```

**Actions:**

- **🌿 Create** - Create a new feature branch with Jira parsing
- **🔀 Switch** - Switch to another branch using fzf
- **⬆️ Update** - Update current branch with latest main/master

**Requirements:**

- `fzf` (fuzzy finder) - will prompt to install if not found
- Homebrew (for automatic fzf installation)

---

### create

Create a new git branch with automatic Jira issue parsing and smart naming. Automatically updates main/master from origin before creating the branch.

**Usage:**

```bash
create [JIRA_LINK] [TITLE...]
```

**Options:**

- `-h, --help` - Show help message

**Features:**

- Updates main/master from origin before creating branch
- Creates branch from latest main/master commit
- Automatically pushes branch to origin and sets up tracking
- Parses Jira issue numbers from URLs or direct input (e.g., `PROJ-123`)
- Falls back to `NOISSUE` if no issue number is found
- Converts titles to lowercase with dashes
- Supports both interactive and one-liner modes
- Automatically switches to the new branch

**Examples:**

```bash
# Interactive mode
$ create
Enter Jira link (e.g., https://jira.company.com/browse/PROJ-123):
> https://jira.company.com/browse/LOVE-123
Parsed issue number: LOVE-123

Enter branch title (will be converted to lowercase with dashes):
> Fix Login Bug

Branch name: feature/LOVE-123-fix-login-bug
Updating 'main' from origin...
✓ 'main' is up to date.
Creating branch...
✓ Successfully created and switched to branch: feature/LOVE-123-fix-login-bug (from main)

# One-liner with Jira URL
$ create https://jira.company.com/browse/LOVE-123 fix login bug
Parsed issue number: LOVE-123
Branch name: feature/LOVE-123-fix-login-bug
Updating 'main' from origin...
✓ 'main' is up to date.
✓ Successfully created and switched to branch: feature/LOVE-123-fix-login-bug (from main)

# One-liner with just issue number
$ create PROJ-456 implement new feature
Parsed issue number: PROJ-456
Branch name: feature/PROJ-456-implement-new-feature
Updating 'main' from origin...
✓ 'main' is up to date.
✓ Successfully created and switched to branch: feature/PROJ-456-implement-new-feature (from main)
Pushing branch to origin and setting up tracking...
✓ Successfully pushed 'feature/PROJ-456-implement-new-feature' to origin with tracking.

# Without Jira issue (uses NOISSUE)
$ create stay logged in in github
Warning: Could not parse issue number from Jira link. Using NOISSUE.
Branch name: feature/NOISSUE-stay-logged-in-in-github
```

**Supported Jira URL formats:**

- `https://jira.company.com/browse/PROJ-123`
- `https://company.atlassian.net/browse/ABC-789`
- `https://jira.atlassian.net/.../selectedIssue=PROJ-123`
- Or just the issue number: `PROJ-123`

---

### switch

Select and switch to a git branch using fzf with interactive preview.

**Usage:**

```bash
switch [FILTER...]
```

**Arguments:**

- `FILTER...` - Optional search filter words to pre-fill fzf (case-insensitive)

**Options:**

- `-h, --help` - Show help message

**Features:**

- Lists local branches first, then remote branches (separated by a visual spacer)
- Remote branches are hidden if a local branch with the same name exists (avoids duplicates)
- Interactive selection with fzf
- Case-insensitive filtering (both `CAPTCHA` and `captcha` match the same branches)
- Optional filter argument(s) to pre-fill search (supports multiple words)
- Live preview showing latest commit info and history
- Automatically switches to selected branch
- For remote branches, creates local tracking branch if needed
- Shows current branch in header

**Examples:**

```bash
$ switch
# Opens fzf selector showing:
Select branch:
Current: main
> local: main
  local: feature/PROJ-123-new-feature
  ─────────────────────────────
  remote: origin/develop
  remote: origin/feature/PROJ-456-another-feature

# Preview shows:
Author: John Doe
Date: 2 hours ago (2025-11-24 14:30)
Message: Add new feature

a1b2c3d Fix bug in authentication
e4f5g6h Update documentation
...

# Select with Enter, automatically switches to branch
✓ Successfully switched to branch: feature/PROJ-123-new-feature

# With filter argument (pre-fills search, case-insensitive)
$ switch captcha
# Opens fzf with 'captcha' already in search box
# Matches: feature/LOVE-123-captcha-validation, feature/CAPTCHA-fix, etc.

$ switch LOVE-456
# Opens fzf filtering for branches containing 'LOVE-456'

# With multiple filter words
$ switch update figma guidelines
# Opens fzf with 'update figma guidelines' pre-filled as filter
```

**Preview Information:**

- **Author** - Latest committer on the branch
- **Date** - Relative time and absolute timestamp
- **Message** - Latest commit message
- **History** - Last 10 commits in oneline format

**Remote Branch Handling:**

- If local tracking branch exists → switches to it
- If no local branch exists → creates and tracks remote branch
- Automatically removes `origin/` prefix from branch name

**Requirements:**

- Must be in a git repository
- `fzf` (fuzzy finder) - will prompt to install if not found

---

### commit

Stage changes and commit with a message. Optionally push to origin.

**Usage:**

```bash
commit [MESSAGE] [OPTIONS]
```

**Options:**

- `-p, --push` - Push to origin after successful commit
- `-h, --help` - Show help message

**Features:**

- Smart staging detection - asks if both staged and unstaged changes exist
- No quotes needed for commit messages
- Optional push in one command
- Interactive mode if no message provided

**Staging Behavior:**

- **Both staged and unstaged changes** → Asks whether to commit staged only or all
- **Only staged changes** → Commits staged changes
- **No staged changes** → Stages all and commits (classic behavior)

**Examples:**

```bash
# Interactive mode
$ commit
Commit message: fix login bug
[main 1a2b3c4] fix login bug
 1 file changed, 5 insertions(+), 2 deletions(-)

# One-liner (no quotes needed!)
$ commit implement new feature
[main 5d6e7f8] implement new feature
 3 files changed, 42 insertions(+), 8 deletions(-)

# With both staged and unstaged changes
$ git add src/app.js
$ # Modified other files too
$ commit fix authentication

You have both staged and unstaged changes.

Commit [s]taged only, or [a]ll changes? (s/a): s
Committing staged changes only...
[main 7h8i9j0] fix authentication
 1 file changed, 10 insertions(+), 3 deletions(-)

# Commit and push
$ commit update documentation -p
[main 9a8b7c6] update documentation
 1 file changed, 10 insertions(+), 3 deletions(-)
Pushing 'main' to origin...
✓ Successfully pushed 'main' to origin.

# Push flag first also works
$ commit -p hotfix: critical bug
[main 3c2d1e0] hotfix: critical bug
 2 files changed, 15 insertions(+), 5 deletions(-)
Pushing 'main' to origin...
✓ Successfully pushed 'main' to origin.
```

**Workflow Integration:**

Works great with the [`status`](#status) command for selective staging:

```bash
$ status          # Interactively stage files
$ commit fix bug  # Commits only what you staged
```

---

### status

Interactive git status viewer with fzf for managing staged and unstaged changes.

**Usage:**

```bash
status
```

**Options:**

- `-h, --help` - Show help message

**Features:**

- Lists all modified, staged, and untracked files
- Interactive file navigation with fzf
- Case-insensitive filtering
- Live diff preview with syntax highlighting (uses delta if available)
- Toggle staging by pressing Enter on any file
- Continuous loop for staging multiple files
- Shows staging status next to each file

**File Status Indicators:**

- `[STAGED]` - File is staged for commit
- `[UNSTAGED]` - File has unstaged changes
- `[UNTRACKED]` - File is not tracked by git

**Examples:**

```bash
$ status
Git Status >
Enter: toggle stage | ESC: exit
> [UNSTAGED]   M  src/app.js
  [STAGED]     A  src/new-feature.js
  [UNTRACKED]  ?? temp.txt
  [UNSTAGED]   M  README.md

# Preview shows diff for selected file:
=== UNSTAGED CHANGES ===

- const user = getUser();
+ const user = await getUser();
+ const profile = await getProfile(user.id);

# Press Enter to stage src/app.js
Staging: src/app.js

# Status refreshes automatically
> [STAGED]     M  src/app.js
  [STAGED]     A  src/new-feature.js
  [UNTRACKED]  ?? temp.txt
  [UNSTAGED]   M  README.md

# Press Enter again to unstage
Unstaging: src/app.js

# Press ESC to exit
Exited status viewer.
```

**Navigation:**

- `↑/↓` or `j/k` - Navigate through files
- `Enter` - Toggle staging for selected file
- `ESC/Ctrl-C` - Exit the viewer

**Preview Types:**

- **Staged files** - Shows cached diff (and unstaged changes if any)
- **Unstaged files** - Shows working tree diff with syntax highlighting
- **Untracked files** - Shows file contents (uses `bat` if available)

**Toggle Actions:**

- `[STAGED]` → unstaged with `git reset HEAD <file>`
- `[UNSTAGED]` → staged with `git add <file>`
- `[UNTRACKED]` → added with `git add <file>`

**Syntax Highlighting:**

- Uses `delta` for enhanced diff highlighting if installed
- Falls back to standard git colored diff
- Uses `bat` for untracked file preview if available

**Requirements:**

- Must be in a git repository
- `fzf` (fuzzy finder) - will prompt to install if not found

**Recommended:**

- `delta` - Enhanced diff syntax highlighting (`brew install git-delta`)
- `bat` - Better file preview (`brew install bat`)

**Workflow Example:**

```bash
# Review and selectively stage changes
$ status
# Navigate and press Enter to stage desired files
# Press ESC when done

# Commit only what you staged
$ commit fix: update user authentication logic
```

---

### commit

Stage all changes and commit with a message. Optionally push to origin.

---

### pr

Open the current branch's pull request in your browser.

**Usage:**

```bash
pr [OPTIONS]
```

**Options:**

- `-p, --push` - Push current branch to origin before opening PR
- `-h, --help` - Show help message

**Features:**

- Opens existing PR or GitHub's compare page to create one
- Optional push before opening PR URL
- Works with both SSH and HTTPS remote URLs
- Automatically URL-encodes branch names
- Opens in your default browser

**Examples:**

```bash
$ pr
# Opens: https://github.com/user/repo/compare/feature-branch?expand=1

$ git checkout feature/helix/LOVE-123-fix-bug
$ pr
# Opens: https://github.com/user/repo/compare/feature/helix/LOVE-123-fix-bug?expand=1

# Push before opening PR
$ pr -p
Pushing 'feature-branch' to origin...
✓ Successfully pushed 'feature-branch' to origin.
# Opens: https://github.com/user/repo/compare/feature-branch?expand=1
```

**Requirements:**

- Must be inside a git repository
- Must have an `origin` remote configured

---

### update

Update the current feature branch with the latest changes from main/master.

**Usage:**

```bash
update [OPTIONS]
```

**Options:**

- `-p, --push` - Push to origin after successful merge
- `-h, --help` - Show help message

**Features:**

- Automatically detects `main` or `master` as base branch
- Fetches latest base branch without switching branches
- Merges into current branch
- Opens configured merge tool if conflicts occur
- Optional push after successful merge

**Examples:**

```bash
$ git checkout feature/LOVE-123-new-feature
$ update
Fetching latest 'main' from origin...
Merging updated 'main' into 'feature/LOVE-123-new-feature'...
✓ 'feature/LOVE-123-new-feature' is now up-to-date with 'main'.

# With push
$ update --push
Fetching latest 'main' from origin...
Merging updated 'main' into 'feature/LOVE-123-new-feature'...
✓ 'feature/LOVE-123-new-feature' is now up-to-date with 'main'.
Pushing 'feature/LOVE-123-new-feature' to origin...
✓ Successfully pushed 'feature/LOVE-123-new-feature' to origin.

# When conflicts occur
$ update
Fetching latest 'main' from origin...
Merging updated 'main' into 'feature/dev-branch'...
⚠ Merge completed with conflicts. Resolve them manually.
# Opens configured merge tool (e.g., Fork, VS Code, GitKraken)
```

**Configuration:**
Set `ZSH_FUNCTIONS_GIT_MERGE_COMMAND` to your preferred merge tool:

- `fork` - Fork Git Client
- `code` - VS Code
- `gitkraken` - GitKraken
- Or any other executable

**Requirements:**

- Must be in a git repository
- Must be on a feature branch (not main/master)
- Remote `origin` must exist

---

### stash

Create a git stash with a descriptive name.

**Usage:**

```bash
stash [NAME...]
```

**Options:**

- `-h, --help` - Show help message

**Features:**

- Stashes all changed files (staged and unstaged)
- Custom stash message for easy identification
- Interactive mode if no name provided
- Includes untracked files

**Examples:**

```bash
# Interactive mode (prompts for name)
$ stash
Stash name: work in progress on login
✓ Created stash: work in progress on login

# Direct mode (name as arguments)
$ stash fix for authentication bug
✓ Created stash: fix for authentication bug

# View your stashes
$ git stash list
stash@{0}: On main: fix for authentication bug
stash@{1}: On main: work in progress on login
```

**Requirements:**

- Must be in a git repository
- Must have changes to stash

---

### stashes

Interactive menu to manage git stashes with fuzzy finding.

**Usage:**

```bash
stashes
```

**Options:**

- `-h, --help` - Show help message

**Features:**

- Interactive action selection menu
- Choose between creating, applying, or cleaning up stashes
- Powered by fzf for intuitive selection
- Case-insensitive filtering
- Auto-installs fzf if missing (with permission)

**Examples:**

```bash
$ stashes
Stash action >
> 💾 Stash - Create a new stash with a name
  📦 Unstash - Apply and optionally drop a stash
  🗑️  Clean up - Delete stashes without applying
  ✖ Abort

# Navigate with ↑/↓ or j/k, press Enter to select
```

**Actions:**

- **💾 Stash** - Create a new stash with all changes
- **📦 Unstash** - Apply a stash to your working directory, optionally drop it
- **🗑️ Clean up** - Delete stashes without applying (supports multi-select)

**Requirements:**

- `fzf` (fuzzy finder) - will prompt to install if not found
- Homebrew (for automatic fzf installation)

---

### unstash

Apply a git stash to your working directory with optional removal.

**Usage:**

```bash
unstash
```

**Options:**

- `-h, --help` - Show help message

**Features:**

- Single-select stash picker with fzf
- Case-insensitive filtering
- Live preview of stash contents
- Apply stash to working directory
- Optional confirmation to drop stash after applying

**Examples:**

```bash
$ unstash
Available stashes >
> stash@{0}: WIP on main: 1a2b3c4 commit message
  stash@{1}: WIP on feature: 5d6e7f8 another commit
  stash@{2}: On dev: 9a8b7c6 old work
  ✖ Abort

# Navigate and preview with ↑/↓, press Enter to select

Applying stash@{1} ...
On branch main
Changes not staged for commit:
  modified:   src/app.js

Drop stash@{1} now? (y/N): y
Dropping stash@{1} ...
Dropped stash@{1} (5d6e7f8abcd...)
```

**Navigation:**

- `↑/↓` or `j/k` - Navigate through stashes
- `Enter` - Select and apply stash
- `ESC/Ctrl-C` - Abort

**Workflow:**

1. Select a stash from the list
2. Preview shows the full diff
3. Stash is applied to your working directory
4. Choose whether to drop (delete) the stash or keep it

**Requirements:**

- `fzf` (fuzzy finder)
- At least one stash in `git stash list`

---

### cleanstash

Delete git stashes without applying them.

**Usage:**

```bash
cleanstash
```

**Options:**

- `-h, --help` - Show help message

**Features:**

- Multi-select support (use TAB to select multiple stashes)
- Case-insensitive filtering
- Live preview of stash contents
- Confirmation prompt before deletion
- Safe deletion (deletes in reverse order to maintain indices)

**Examples:**

```bash
$ cleanstash
Available stashes >
> stash@{0}: WIP on main: 1a2b3c4 commit message
  stash@{1}: WIP on feature: 5d6e7f8 another commit
  stash@{2}: On dev: 9a8b7c6 old work
  ✖ Abort

# Use TAB to select multiple stashes, press Enter to confirm

Selected stashes to delete:
  - stash@{0}
  - stash@{2}

Delete these 2 stash(es)? (y/N): y
Deleting stashes...
Dropping stash@{2} ...
✓ Deleted stash@{2}
Dropping stash@{0} ...
✓ Deleted stash@{0}
```

**Navigation:**

- `↑/↓` or `j/k` - Navigate through stashes
- `TAB` - Select/deselect stash (multi-select)
- `Enter` - Confirm selection
- `ESC/Ctrl-C` - Abort

**Notes:**

- Stashes are deleted in reverse order to prevent index shifts
- Preview shows the full diff of the selected stash
- No changes are applied to your working directory

**Requirements:**

- `fzf` (fuzzy finder)
- At least one stash in `git stash list`

---

## Requirements

### Required

- **zsh** - The Z shell
- **git** - Version control system

### Optional

- **fzf** - Fuzzy finder for interactive menus (required for `switch`, `status`, `stashes`, `unstash`, `cleanstash`)
  - Install with: `brew install fzf`
  - Auto-install prompt included in commands that require it
- **delta** - Enhanced diff syntax highlighting (recommended for `status`)
  - Install with: `brew install git-delta`
- **bat** - Better file preview with syntax highlighting (recommended for `status`)
  - Install with: `brew install bat`
- **Homebrew** - For automatic installation of optional dependencies on macOS

### Recommended

- Configure `ZSH_FUNCTIONS_GIT_MERGE_COMMAND` for better merge conflict resolution
- Popular options: Fork, VS Code, GitKraken, Sublime Merge

---

## Tips & Tricks

### Aliases

Add these to your `~/.zshrc` for even faster workflows:

```bash
alias b='branch'
alias cr='create'
alias sw='switch'
alias st='status'
alias c='commit'
alias cp='commit -p'
alias u='update'
alias up='update -p'
```

## License

See [LICENSE](LICENSE) file for details.
