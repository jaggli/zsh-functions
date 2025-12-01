# Cleanup local branches that are no longer needed
cleanup() {
    # -----------------------------
    # 0. Check for help flag
    # -----------------------------
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        cat << 'EOF'
Usage: cleanup

Find and delete local branches that are no longer needed.

Categories (pre-selected for deletion):
  - Merged branches: Local branches whose remote was merged and deleted
  - Stale branches: Local branches with no commits in 7+ days

Not pre-selected (but listed):
  - Recent branches: Local branches with commits in the last 7 days

Navigation:
  ↑/↓ or j/k    Navigate through branches
  TAB           Select/deselect branch
  Enter         Delete selected branch(es)
  ESC/Ctrl-C    Exit without action

Notes:
  - Only deletes LOCAL branches (never touches remote)
  - If current branch is selected, switches to main/master first
  - Force deletes branches (even if not fully merged)

Examples:
  $ cleanup
  Local branches to clean up >
  > [MERGED]  feature/old-feature        2 weeks ago
    [STALE]   feature/abandoned          8 days ago
    [RECENT]  feature/work-in-progress   2 days ago
    ✖ Abort

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
    # 2. Fetch and prune to sync with remote
    # -----------------------------
    echo "Fetching and pruning remote..."
    git fetch --prune origin 2>/dev/null

    # -----------------------------
    # 3. Detect base branch
    # -----------------------------
    local base_branch
    if git show-ref --verify --quiet refs/heads/main; then
        base_branch="main"
    elif git show-ref --verify --quiet refs/heads/master; then
        base_branch="master"
    else
        echo "Could not detect 'main' or 'master' locally."
        return 1
    fi

    local current_branch
    current_branch=$(git rev-parse --abbrev-ref HEAD)

    # -----------------------------
    # 4. Build branch lists
    # -----------------------------
    local abort_label="✖ Abort"
    local one_week_ago
    one_week_ago=$(date -v-7d +%s 2>/dev/null || date -d "7 days ago" +%s 2>/dev/null)

    # Get list of remote branches (without origin/ prefix)
    local remote_branches
    remote_branches=$(git for-each-ref --format='%(refname:short)' refs/remotes/origin | sed 's|^origin/||' | grep -v '^HEAD$')

    # Arrays to hold branches by category
    local merged_branches=()
    local stale_branches=()
    local recent_branches=()

    # Process each local branch
    while IFS= read -r branch; do
        # Skip base branch
        [[ "$branch" == "$base_branch" ]] && continue
        [[ -z "$branch" ]] && continue

        # Get last commit date for all branches
        local last_commit_ts
        last_commit_ts=$(git log -1 --format='%ct' "$branch" 2>/dev/null)
        local relative_date
        relative_date=$(git log -1 --format='%cr' "$branch" 2>/dev/null)
        
        # Check if remote branch exists
        local has_remote=false
        if echo "$remote_branches" | grep -qx "$branch"; then
            has_remote=true
        fi

        # Check if it HAD an upstream (was pushed before)
        local configured_upstream
        configured_upstream=$(git config "branch.$branch.remote" 2>/dev/null)

        if [[ "$has_remote" == false && -n "$configured_upstream" ]]; then
            # Had upstream but remote is gone = merged and deleted remotely
            merged_branches+=("$branch|$relative_date")
        elif [[ -n "$last_commit_ts" && "$last_commit_ts" -lt "$one_week_ago" ]]; then
            # Stale: no commits in 7+ days (pre-select for deletion)
            stale_branches+=("$branch|$relative_date")
        else
            # Recent: has recent activity (don't pre-select)
            recent_branches+=("$branch|$relative_date")
        fi
    done < <(git for-each-ref --format='%(refname:short)' refs/heads)

    # -----------------------------
    # 5. Build fzf input with pre-selection markers
    # -----------------------------
    local branch_list=""
    local preselect_list=""
    local idx=0
    local max_branch_len=60

    # Add merged branches (pre-selected)
    for entry in "${merged_branches[@]}"; do
        local branch="${entry%%|*}"
        local date="${entry#*|}"
        local display_branch="$branch"
        if [[ ${#display_branch} -gt $max_branch_len ]]; then
            display_branch="${display_branch:0:$((max_branch_len - 3))}..."
        fi
        local line=$(printf "[MERGED]  %-${max_branch_len}s  %s\t%s" "$display_branch" "$date" "$branch")
        branch_list+="$line\n"
        preselect_list+="$line\n"
        ((idx++))
    done

    # Add stale branches (pre-selected)
    for entry in "${stale_branches[@]}"; do
        local branch="${entry%%|*}"
        local date="${entry#*|}"
        local display_branch="$branch"
        if [[ ${#display_branch} -gt $max_branch_len ]]; then
            display_branch="${display_branch:0:$((max_branch_len - 3))}..."
        fi
        local line=$(printf "[STALE]   %-${max_branch_len}s  %s\t%s" "$display_branch" "$date" "$branch")
        branch_list+="$line\n"
        preselect_list+="$line\n"
        ((idx++))
    done

    # Add recent branches (not pre-selected)
    for entry in "${recent_branches[@]}"; do
        local branch="${entry%%|*}"
        local date="${entry#*|}"
        local display_branch="$branch"
        if [[ ${#display_branch} -gt $max_branch_len ]]; then
            display_branch="${display_branch:0:$((max_branch_len - 3))}..."
        fi
        local line=$(printf "[RECENT]  %-${max_branch_len}s  %s\t%s" "$display_branch" "$date" "$branch")
        branch_list+="$line\n"
        ((idx++))
    done

    if [[ -z "$branch_list" ]]; then
        echo "No local branches to clean up."
        return 0
    fi

    # Add abort option
    branch_list+="$abort_label\t\t"

    # Create temp files
    local branch_file=$(mktemp)
    local preselect_file=$(mktemp)
    echo -e "$branch_list" > "$branch_file"
    echo -e "$preselect_list" > "$preselect_file"

    # -----------------------------
    # 6. Run fzf picker
    # -----------------------------
    local total_count=$((${#merged_branches[@]} + ${#stale_branches[@]} + ${#recent_branches[@]}))
    local preselect_count=$((${#merged_branches[@]} + ${#stale_branches[@]}))

    # Build toggle sequence for pre-selection (toggle first N items)
    local toggle_sequence="first"
    for ((i=0; i<preselect_count; i++)); do
        toggle_sequence+="+toggle+down"
    done
    toggle_sequence+="+first"

    local selection
    selection=$(cat "$branch_file" | fzf \
        --prompt="Local branches to clean up > " \
        -i \
        --reverse \
        --border \
        --header="[TAB] toggle | [Enter] delete selected | [ESC] exit
Found $total_count branches ($preselect_count pre-selected for deletion)" \
        --multi \
        --delimiter=$'\t' \
        --with-nth=1 \
        --bind=enter:accept \
        --preview='
            line={}
            if [[ "$line" == "✖ Abort"* ]]; then
                echo "Exit without action";
            else
                branch=$(echo "$line" | cut -f2)
                echo "Branch: $branch";
                echo "";
                echo "Recent commits:";
                git log --oneline --color=always -n 15 "$branch" 2>/dev/null || echo "No commits found";
            fi
        ' \
        --preview-window=right:35% \
        --bind "load:$toggle_sequence"
    )

    # Cleanup temp files
    rm -f "$branch_file" "$preselect_file"

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
    # 7. Extract branch names and confirm deletion
    # -----------------------------
    local branches_to_delete=()
    local need_switch=false

    while IFS= read -r line; do
        [[ "$line" == "✖ Abort"* ]] && continue
        local branch_name
        branch_name=$(echo "$line" | cut -f2)
        if [[ -n "$branch_name" ]]; then
            branches_to_delete+=("$branch_name")
            if [[ "$branch_name" == "$current_branch" ]]; then
                need_switch=true
            fi
        fi
    done <<< "$selection"

    if [[ ${#branches_to_delete[@]} -eq 0 ]]; then
        echo "No branches selected."
        return 0
    fi

    echo ""
    echo "Selected local branches to delete:"
    for branch in "${branches_to_delete[@]}"; do
        if [[ "$branch" == "$current_branch" ]]; then
            echo "  - $branch (current branch)"
        else
            echo "  - $branch"
        fi
    done
    
    if [[ "$need_switch" == true ]]; then
        echo ""
        echo "Note: Will switch to '$base_branch' first (current branch selected for deletion)"
    fi
    echo ""

    read "confirm?Delete these ${#branches_to_delete[@]} local branch(es)? (y/N): "
    case "$confirm" in
        [yY][eE][sS]|[yY])
            # Switch to base branch if needed
            if [[ "$need_switch" == true ]]; then
                echo "Switching to '$base_branch'..."
                git checkout "$base_branch" || {
                    echo "⚠ Failed to switch to '$base_branch'. Aborting deletion."
                    return 1
                }
            fi

            echo "Deleting branches..."
            for branch in "${branches_to_delete[@]}"; do
                echo "Deleting $branch ..."
                if git branch -D "$branch" 2>/dev/null; then
                    echo "✓ Deleted $branch"
                else
                    echo "✗ Failed to delete $branch"
                fi
            done
            ;;
        *)
            echo "Deletion cancelled."
            ;;
    esac
}
