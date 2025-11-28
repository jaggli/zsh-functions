stash() {
    # -----------------------------
    # 0. Check for help flag
    # -----------------------------
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        cat << 'EOF'
Usage: stash [NAME...]

Create a git stash with a descriptive name.
If no name is provided, prompts for one interactively.

Options:
  -h, --help    Show this help message

Features:
  - Stashes all changed files (staged and unstaged)
  - Custom stash message for easy identification
  - Interactive mode if no name provided
  - Works with untracked files

Examples:
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

Requirements:
  - Must be in a git repository
  - Must have changes to stash (staged, unstaged, or untracked)

See also:
  stashes -h     Show help for stashes menu
  unstash -h     Show help for unstash command
  cleanstash -h  Show help for cleanstash command

EOF
        return 0
    fi

    # -----------------------------
    # 1. Check if inside a git repository
    # -----------------------------
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "Error: Not inside a git repository."
        return 1
    fi

    # -----------------------------
    # 2. Check for changes to stash
    # -----------------------------
    if git diff --quiet && git diff --cached --quiet && [[ -z "$(git ls-files --others --exclude-standard)" ]]; then
        echo "No changes to stash."
        return 1
    fi

    # -----------------------------
    # 3. Get stash name
    # -----------------------------
    local stash_name

    if [[ $# -gt 0 ]]; then
        # Name provided as arguments
        stash_name="$*"
    else
        # Interactive mode - prompt for name
        echo -n "Stash name: "
        read -r stash_name

        if [[ -z "$stash_name" ]]; then
            echo "Error: Stash name cannot be empty."
            return 1
        fi
    fi

    # -----------------------------
    # 4. Create the stash
    # -----------------------------
    if git stash push -u -m "$stash_name"; then
        echo "✓ Created stash: $stash_name"
    else
        echo "Error: Failed to create stash."
        return 1
    fi
}
