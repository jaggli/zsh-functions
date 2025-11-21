# zsh-functions

A collection of powerful zsh utilities to streamline your git/GitHub workflow. These functions provide interactive, user-friendly interfaces for common git operations with smart defaults and helpful prompts.

## Table of Contents

- [Installation](#installation)
- [Configuration](#configuration)
- [Commands](#commands)
  - [branch](#branch)
  - [commit](#commit)
  - [pr](#pr)
  - [update](#update)
  - [stash](#stash)
  - [unstash](#unstash)
  - [cleanstash](#cleanstash)
- [Requirements](#requirements)

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

Create a new git branch with automatic Jira issue parsing and smart naming.

**Usage:**

```bash
branch [JIRA_LINK] [TITLE...]
```

**Options:**

- `-h, --help` - Show help message

**Features:**

- Parses Jira issue numbers from URLs automatically
- Falls back to `NOISSUE` if no issue number is found
- Converts titles to lowercase with dashes
- Supports both interactive and one-liner modes
- Automatically switches to the new branch

**Examples:**

```bash
# Interactive mode
$ branch
Enter Jira link (e.g., https://jira.company.com/browse/PROJ-123):
> https://jira.company.com/browse/LOVE-123
Parsed issue number: LOVE-123

Enter branch title (will be converted to lowercase with dashes):
> Fix Login Bug

Branch name: feature/LOVE-123-fix-login-bug

# One-liner with Jira URL
$ branch https://jira.company.com/browse/LOVE-123 fix login bug
Parsed issue number: LOVE-123
Branch name: feature/LOVE-123-fix-login-bug

# One-liner with just issue number
$ branch PROJ-456 implement new feature
Parsed issue number: PROJ-456
Branch name: feature/PROJ-456-implement-new-feature

# Without Jira issue (uses NOISSUE)
$ branch stay logged in in github
Warning: Could not parse issue number from Jira link. Using NOISSUE.
Branch name: feature/NOISSUE-stay-logged-in-in-github
```

**Supported Jira URL formats:**

- `https://jira.company.com/browse/PROJ-123`
- `https://company.atlassian.net/browse/ABC-789`
- `https://jira.atlassian.net/.../selectedIssue=PROJ-123`
- Or just the issue number: `PROJ-123`

---

### commit

Stage all changes and commit with a message. Optionally push to origin.

**Usage:**

```bash
commit [MESSAGE] [OPTIONS]
```

**Options:**

- `-p, --push` - Push to origin after successful commit
- `-h, --help` - Show help message

**Features:**

- Automatically stages all changes (`git add -A`)
- No quotes needed for commit messages
- Optional push in one command
- Interactive mode if no message provided

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

Interactive menu to manage git stashes with fuzzy finding.

**Usage:**

```bash
stash
```

**Options:**

- `-h, --help` - Show help message

**Features:**

- Interactive action selection menu
- Choose between unstashing or cleaning up stashes
- Powered by fzf for intuitive selection
- Auto-installs fzf if missing (with permission)

**Examples:**

```bash
$ stash
Stash action >
> 📦 Unstash - Apply and optionally drop a stash
  🗑️  Clean up - Delete stashes without applying
  ✖ Abort

# Navigate with ↑/↓ or j/k, press Enter to select
```

**Actions:**

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

- **fzf** - Fuzzy finder for interactive menus (required for `stash`, `unstash`, `cleanstash`)
  - Install with: `brew install fzf`
  - Auto-install prompt included in stash commands
- **Homebrew** - For automatic fzf installation on macOS

### Recommended

- Configure `ZSH_FUNCTIONS_GIT_MERGE_COMMAND` for better merge conflict resolution
- Popular options: Fork, VS Code, GitKraken, Sublime Merge

---

## Tips & Tricks

### Aliases

Add these to your `~/.zshrc` for even faster workflows:

```bash
alias b='branch'
alias c='commit'
alias cp='commit -p'
alias u='update'
alias up='update -p'
```

### Workflow Example

```bash
# Create a new feature branch
$ branch PROJ-123 add user authentication

# Make your changes...

# Commit and push
$ commit -p implement login form

# Keep branch up to date with main
$ update

# More changes...
$ commit -p add validation

# Open PR when ready
$ pr
```

---

## License

See [LICENSE](LICENSE) file for details.
