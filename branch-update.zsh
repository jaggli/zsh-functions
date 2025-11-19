# Update the current branch with the latest version of master/main
update() {
  local merge_tool="fork"  # Git client to open for merge conflict resolution
  local should_push=false

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      -h|--help)
        cat << 'EOF'
Usage: update [OPTIONS]

Update the current feature branch with the latest changes from main/master.

Options:
  -p, --push    Push to origin after successful merge
  -h, --help    Show this help message

Behavior:
  1. Detects whether your repo uses 'main' or 'master'
  2. Fetches the latest base branch from origin
  3. Merges it into your current branch
  4. Optionally pushes the updated branch to origin
  5. Opens merge tool (fork) if conflicts occur

Examples:
  $ git checkout feature/helix/LOVE-123-new-feature
  $ update
  Fetching latest 'main' from origin...
  Merging updated 'main' into 'feature/helix/LOVE-123-new-feature'...
  ✓ 'feature/helix/LOVE-123-new-feature' is now up-to-date with 'main'.

  ---

  $ update --push
  Fetching latest 'main' from origin...
  Merging updated 'main' into 'feature/helix/LOVE-123-new-feature'...
  ✓ 'feature/helix/LOVE-123-new-feature' is now up-to-date with 'main'.
  Pushing 'feature/helix/LOVE-123-new-feature' to origin...
  ✓ Successfully pushed 'feature/helix/LOVE-123-new-feature' to origin.

  ---

  $ update -p
  Fetching latest 'main' from origin...
  Merging updated 'main' into 'feature/dev-branch'...
  ⚠ Merge completed with conflicts. Resolve them manually.
  # Opens Fork (or configured merge tool) for conflict resolution

Configuration:
  - Merge tool can be changed by editing the 'merge_tool' variable
  - Default: "fork"
  - Alternatives: "code", "gitkraken", "gitk", etc.

Requirements:
  - Must be in a git repository
  - Must be on a feature branch (not main/master)
  - Remote 'origin' must exist

Notes:
  - Uses fast-forward merge when possible
  - Automatically opens merge tool if conflicts occur
  - Local main/master is updated without checkout

EOF
        return 0
        ;;
      -p|--push)
        should_push=true
        shift
        ;;
      *)
        echo "Unknown option: $1"
        echo "Usage: update [-p|--push]"
        return 1
        ;;
    esac
  done

  # Ensure we're in a git repo
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Not inside a git repository."
    return 1
  fi

  current_branch=$(git rev-parse --abbrev-ref HEAD)

  # Detect base branch: main or master
  if git show-ref --verify --quiet refs/heads/main; then
    base_branch="main"
  elif git show-ref --verify --quiet refs/heads/master; then
    base_branch="master"
  else
    echo "Could not detect 'main' or 'master' locally."
    return 1
  fi

  if [[ "$current_branch" == "$base_branch" ]]; then
    echo "You're already on '$base_branch'. Checkout a feature branch first."
    return 1
  fi

  echo "Fetching latest '$base_branch' from origin..."
  git fetch origin "$base_branch:$base_branch" || {
    echo "⚠ Could not fast-forward local '$base_branch'."
    return 1
  }

  echo "Merging updated '$base_branch' into '$current_branch'..."
  git merge --ff --no-edit "$base_branch"

  if [[ $? -eq 0 ]]; then
    echo "✓ '$current_branch' is now up-to-date with '$base_branch'."
    
    # Push if requested and merge was successful
    if [[ "$should_push" == true ]]; then
      echo "Pushing '$current_branch' to origin..."
      git push origin "$current_branch"
      if [[ $? -eq 0 ]]; then
        echo "✓ Successfully pushed '$current_branch' to origin."
      else
        echo "⚠ Failed to push '$current_branch' to origin."
        return 1
      fi
    fi
  else
    echo "⚠ Merge completed with conflicts. Resolve them manually."

    # Open merge tool for conflict resolution
    if command -v "$merge_tool" >/dev/null 2>&1; then
      "$merge_tool" .
    fi
  fi
}