# zsh-functions

Interactive git utilities for zsh with fzf-powered menus.

## Installation

```bash
mkdir -p ~/.config/zsh && git clone git@github.com:jaggli/zsh-functions.git ~/.config/zsh/zsh-functions
```

Add to `~/.zshrc`:

```bash
export ZSH_FUNCTIONS_FEATURE_BRANCH_PREFIX="feature/"  # Branch prefix (default: feature/)
export ZSH_FUNCTIONS_GIT_MERGE_COMMAND="fork"          # Merge conflict tool (fork/code/gitkraken)

for f in ~/.config/zsh/zsh-functions/*.zsh; do source "$f"; done
```

### Dependencies

```bash
# Required
brew install fzf

# Optional (recommended)
brew install git-delta  # Better diff highlighting
brew install bat        # File preview with syntax highlighting
```

## Commands

### branch

Interactive menu for branch operations (create/switch/update).

### create

```bash
create [JIRA_LINK|ISSUE] [TITLE...]
```

Create feature branch with Jira parsing. Updates main first, pushes and tracks.

```bash
create PROJ-123 fix login bug  # → feature/PROJ-123-fix-login-bug
create                          # Interactive mode
```

### switch

```bash
switch [FILTER...]
```

Switch branches with fzf. Shows local first, then remotes (deduped). Preview shows commit history.

```bash
switch              # Browse all branches
switch captcha      # Pre-filter for "captcha"
```

### commit

```bash
commit [MESSAGE] [-p|--push] [-s|--staged]
```

Commit with optional push. Smart staging: prompts if both staged/unstaged exist.

```bash
commit fix bug           # Commit all
commit -s fix bug        # Commit staged only
commit -p add feature    # Commit and push
```

### status

Interactive staging with fzf. Toggle files with Enter, ESC to exit. Shows diffs in preview.

### pr

```bash
pr [-p|--push]
```

Open PR in browser. `-p` pushes first.

### update

```bash
update [-p|--push]
```

Merge latest main/master into current branch. Opens merge tool on conflicts.

### stale

```bash
stale [-m|--my] [FILTER...]
```

List remote branches >3 months old (oldest first). Multi-select with TAB to delete.

- `Ctrl-A` toggles showing all branches
- `--my` filters by your git username

### stashes

Interactive stash menu: create, apply, or delete stashes.

### stash

```bash
stash [NAME...]
```

Create named stash (includes untracked files).

### unstash

Apply stash with fzf picker. Optionally drop after applying.

### cleanstash

Delete stashes (multi-select with TAB).

### cleanup

```bash
cleanup
```

Find and delete leftover local branches. Shows all local branches categorized:

- **[MERGED]** - Remote was deleted (pre-selected)
- **[STALE]** - No commits in 7+ days (pre-selected)
- **[RECENT]** - Recent activity (not selected)

Switches to main/master first if current branch is selected for deletion.

## License

See [LICENSE](LICENSE) file for details.
