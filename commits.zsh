# List recent commits and optionally revert selected ones
commits() {
    # -----------------------------
    # 0. Check for help flag
    # -----------------------------
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        cat << 'EOF'
Usage: commits [COUNT]

List recent commits in the current branch with option to revert selected ones.

Arguments:
  COUNT         Number of commits to show (default: 20)

Navigation:
  ↑/↓ or j/k    Navigate through commits
  TAB           Select/deselect commit for revert
  Enter         Revert selected commit(s)
  ESC/Ctrl-C    Exit without action

Notes:
  - Shows commits from newest to oldest
  - Preview shows full commit diff
  - Multiple commits can be selected for revert
  - Reverts are done in reverse order (oldest first) to avoid conflicts
  - Each revert creates a new commit

Examples:
  $ commits
  # Shows last 20 commits

  $ commits 50
  # Shows last 50 commits

Requirements:
  - Must be in a git repository
  - fzf (fuzzy finder)

EOF
        return 0
    fi

    # -----------------------------
    # 1. Check prerequisites
    # -----------------------------
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "Not inside a git repository."
        return 1
    fi

    if ! command -v fzf >/dev/null 2>&1; then
        echo "fzf is not installed."
        read "ans?Install fzf with Homebrew? (y/N): "
        case "$ans" in
            [yY][eE][sS]|[yY])
                echo "Installing fzf with brew..."
                if ! command -v brew >/dev/null 2>&1; then
                    echo "Homebrew is not installed. Aborting."
                    return 1
                fi
                brew install fzf || { echo "fzf install failed. Aborting."; return 1; }
                ;;
            *)
                echo "Aborted (skipped fzf installation)."
                return 1
                ;;
        esac
    fi

    # -----------------------------
    # 2. Get commit count
    # -----------------------------
    local count="${1:-20}"
    local abort_label="✖ Abort"
    local current_branch
    current_branch=$(git rev-parse --abbrev-ref HEAD)

    # -----------------------------
    # 3. Build commit list
    # -----------------------------
    local commit_list
    commit_list=$(git log -n "$count" --format="%h|%s|%cr|%an" | while IFS='|' read -r hash subject date author; do
        # Truncate subject if too long
        if [[ ${#subject} -gt 60 ]]; then
            subject="${subject:0:57}..."
        fi
        printf "%-8s  %-60s  %-15s  %s\t%s\n" "$hash" "$subject" "$date" "$author" "$hash"
    done)

    if [[ -z "$commit_list" ]]; then
        echo "No commits found."
        return 0
    fi

    # Add abort option
    commit_list+=$'\n'"$abort_label"$'\t'

    # Create temp file
    local commit_file=$(mktemp)
    echo "$commit_list" > "$commit_file"

    # -----------------------------
    # 4. Run fzf picker
    # -----------------------------
    local selection
    selection=$(cat "$commit_file" | fzf \
        --prompt="Commits on '$current_branch' > " \
        -i \
        --reverse \
        --border \
        --header="[TAB] select for revert | [Enter] revert selected | [ESC] exit
Showing last $count commits" \
        --multi \
        --delimiter=$'\t' \
        --with-nth=1 \
        --bind=enter:accept \
        --preview='
            line={}
            if [[ "$line" == "✖ Abort"* ]]; then
                echo "Exit without action";
            else
                hash=$(echo "$line" | cut -f2)
                echo "Commit: $hash";
                echo "";
                git show --stat --color=always "$hash" 2>/dev/null;
                echo "";
                echo "─────────────────────────────────────────────────────";
                echo "";
                git show --color=always "$hash" 2>/dev/null | head -100;
            fi
        ' \
        --preview-window=right:50%
    )

    # Cleanup temp file
    rm -f "$commit_file"

    # ESC or Ctrl-C
    if [[ -z "$selection" ]]; then
        echo "Exited."
        return 0
    fi

    # Abort option
    if echo "$selection" | grep -q "^$abort_label"; then
        echo "Aborted."
        return 0
    fi

    # -----------------------------
    # 5. Extract commit hashes and confirm revert
    # -----------------------------
    local commits_to_revert=()

    while IFS= read -r line; do
        [[ "$line" == "✖ Abort"* ]] && continue
        local hash
        hash=$(echo "$line" | cut -f2)
        if [[ -n "$hash" ]]; then
            commits_to_revert+=("$hash")
        fi
    done <<< "$selection"

    if [[ ${#commits_to_revert[@]} -eq 0 ]]; then
        echo "No commits selected."
        return 0
    fi

    echo ""
    echo "Selected commits to revert:"
    for hash in "${commits_to_revert[@]}"; do
        local subject
        subject=$(git log -1 --format="%s" "$hash")
        echo "  - $hash: $subject"
    done
    echo ""

    read "confirm?Revert these ${#commits_to_revert[@]} commit(s)? (y/N): "
    case "$confirm" in
        [yY][eE][sS]|[yY])
            echo "Reverting commits..."
            
            # Reverse the array to revert oldest first (avoids conflicts)
            local reversed=()
            for ((i=${#commits_to_revert[@]}-1; i>=0; i--)); do
                reversed+=("${commits_to_revert[$i]}")
            done

            for hash in "${reversed[@]}"; do
                echo "Reverting $hash ..."
                if git revert --no-edit "$hash"; then
                    echo "✓ Reverted $hash"
                else
                    echo "✗ Failed to revert $hash (conflict?)"
                    echo "  Resolve the conflict and run 'git revert --continue'"
                    return 1
                fi
            done
            echo ""
            echo "✓ All selected commits reverted."
            ;;
        *)
            echo "Revert cancelled."
            ;;
    esac
}
