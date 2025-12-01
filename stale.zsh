stale() {
    # -----------------------------
    # 0. Check for help flag
    # -----------------------------
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        cat << 'EOF'
Usage: stale [OPTIONS] [FILTER...]

Show a list of remote branches ordered by last modification date (oldest first).
Useful for identifying stale branches that may need cleanup.

Arguments:
  FILTER...     Optional search filter words to pre-fill fzf (joined with spaces)

Options:
  -h, --help    Show this help message
  -m, --my      Pre-fill filter with your git username (from git config user.name)

Features:
  - Lists all remote branches sorted by last commit date (oldest first)
  - By default, only shows branches older than 3 months (truly stale)
  - Shows branch name, relative date, and author
  - Interactive selection with fzf
  - Preview shows recent commits on the selected branch
  - Delete selected branches directly from the list

Navigation:
  ↑/↓ or j/k    Navigate through branches
  TAB           Select/deselect branch (multi-select)
  Ctrl-A        Toggle showing all branches (including recent ones)
  Enter         Delete selected branch(es)
  ESC/Ctrl-C    Exit without action

Examples:
  $ stale
  Stale branches (oldest first) >
  > feature/old-feature                    3 months ago    John Doe
    feature/another-old-one                4 months ago    Jane Smith
    feature/very-old                       6 months ago    Bob Wilson
    ✖ Abort

  # Press Ctrl-A to show all branches including recent ones
  # Select branches with TAB, press Enter to delete

  $ stale --my
  # Pre-fills fzf filter with your git username to show only your branches

  $ stale Product refactoring
  # Pre-fills fzf filter with "Product refactoring"

Output format:
  <branch-name>                            <relative-date>  <author>

Requirements:
  - Must be in a git repository
  - fzf (fuzzy finder) - will prompt to install if not found

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
                if [[ -f "$(brew --prefix)/opt/fzf/install" ]]; then
                    echo "Running fzf install script..."
                    yes | "$(brew --prefix)/opt/fzf/install"
                fi
                ;;
            *)
                echo "Aborted (skipped fzf installation)."
                return 1
                ;;
        esac
    fi

    # -----------------------------
    # 2. Handle filter (--my flag or arbitrary words)
    # -----------------------------
    local filter=""
    if [[ "$1" == "-m" || "$1" == "--my" ]]; then
        filter=$(git config user.name)
        if [[ -z "$filter" ]]; then
            echo "Warning: git config user.name is not set."
        fi
    elif [[ $# -gt 0 ]]; then
        filter="$*"
    fi

    # -----------------------------
    # 3. Fetch latest from remote
    # -----------------------------
    echo "Fetching latest from remote..."
    git fetch --prune origin 2>/dev/null

    # -----------------------------
    # 4. Build branch list sorted by date (oldest first)
    # -----------------------------
    local abort_label="✖ Abort"
    local max_branch_length=65
    
    # Calculate date 3 months ago
    local three_months_ago
    three_months_ago=$(date -v-3m +%s 2>/dev/null || date -d "3 months ago" +%s 2>/dev/null)
    
    # Build full branch list (all branches)
    # Format: display_branch | date | author | full_branch (tab-separated, last field is full branch for operations)
    local all_branch_list
    all_branch_list=$(git for-each-ref --sort=committerdate --format='%(refname:short)|%(committerdate:relative)|%(authorname)|%(committerdate:unix)' refs/remotes/origin | \
        grep -v 'origin/HEAD' | \
        grep -v '^origin$' | \
        while IFS='|' read -r branch date author timestamp; do
            # Remove origin/ prefix for display
            local full_branch="${branch#origin/}"
            local display_branch="$full_branch"
            # Truncate branch name if too long
            if [[ ${#display_branch} -gt $max_branch_length ]]; then
                display_branch="${display_branch:0:$((max_branch_length - 3))}..."
            fi
            # Format: display branch (padded), date, author, TAB, full branch name
            printf "%-${max_branch_length}s  %-20s %-25s\t%s\n" "$display_branch" "$date" "$author" "$full_branch"
        done)
    
    # Build stale branch list (only branches older than 3 months)
    local stale_branch_list
    stale_branch_list=$(git for-each-ref --sort=committerdate --format='%(refname:short)|%(committerdate:relative)|%(authorname)|%(committerdate:unix)' refs/remotes/origin | \
        grep -v 'origin/HEAD' | \
        grep -v '^origin$' | \
        while IFS='|' read -r branch date author timestamp; do
            # Only include if older than 3 months
            if [[ "$timestamp" -lt "$three_months_ago" ]]; then
                # Remove origin/ prefix for display
                local full_branch="${branch#origin/}"
                local display_branch="$full_branch"
                # Truncate branch name if too long
                if [[ ${#display_branch} -gt $max_branch_length ]]; then
                    display_branch="${display_branch:0:$((max_branch_length - 3))}..."
                fi
                # Format: display branch (padded), date, author, TAB, full branch name
                printf "%-${max_branch_length}s  %-20s %-25s\t%s\n" "$display_branch" "$date" "$author" "$full_branch"
            fi
        done)

    if [[ -z "$all_branch_list" ]]; then
        echo "No remote branches found."
        return 0
    fi
    
    # Create temp files for fzf reload
    local stale_file=$(mktemp)
    local all_file=$(mktemp)
    echo "$stale_branch_list" > "$stale_file"
    echo "$abort_label" >> "$stale_file"
    echo "$all_branch_list" > "$all_file"
    echo "$abort_label" >> "$all_file"

    # -----------------------------
    # 5. Run fzf picker with preview
    # -----------------------------
    local stale_count=$(echo "$stale_branch_list" | grep -c . || echo "0")
    local all_count=$(echo "$all_branch_list" | grep -c . || echo "0")
    
    local selection
    selection=$(
        cat "$stale_file" | fzf \
            --prompt="Stale branches (>3 months, oldest first) > " \
            --query="$filter" \
            -i \
            --reverse \
            --border \
            --header="[TAB] select | [Ctrl-A] show all ($all_count) | [Enter] delete | [ESC] exit
Showing $stale_count stale branches (older than 3 months)" \
            --multi \
            --delimiter=$'\t' \
            --with-nth=1 \
            --bind=enter:accept \
            --bind="ctrl-a:reload(cat $all_file)+change-prompt(All branches (oldest first) > )+change-header([TAB] select | [Ctrl-A] show all ($all_count) | [Enter] delete | [ESC] exit
Showing all $all_count branches)" \
            --preview='
                line={}
                if [[ "$line" == "✖ Abort" ]]; then
                    echo "Exit without action";
                else
                    # Extract full branch name (after tab)
                    branch=$(echo "$line" | cut -f2)
                    echo "Branch: origin/$branch";
                    echo "";
                    echo "Recent commits:";
                    git log --oneline --color=always -n 15 "origin/$branch" 2>/dev/null || echo "No commits found";
                fi
            ' \
            --preview-window=right:35%
    )
    
    # Cleanup temp files
    rm -f "$stale_file" "$all_file"

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
    # 6. Extract branch names and confirm deletion
    # -----------------------------
    local branches_to_delete=()
    while IFS= read -r line; do
        # Skip abort option
        if [[ "$line" == "✖ Abort" ]]; then
            continue
        fi
        # Extract full branch name (after tab)
        local branch_name
        branch_name=$(echo "$line" | cut -f2)
        if [[ -n "$branch_name" ]]; then
            branches_to_delete+=("$branch_name")
        fi
    done <<< "$selection"

    if [[ ${#branches_to_delete[@]} -eq 0 ]]; then
        echo "No branches selected."
        return 0
    fi

    echo ""
    echo "Selected branches to delete from remote:"
    for branch in "${branches_to_delete[@]}"; do
        echo "  - origin/$branch"
    done
    echo ""

    read "confirm?Delete these ${#branches_to_delete[@]} branch(es) from remote? (y/N): "
    case "$confirm" in
        [yY][eE][sS]|[yY])
            echo "Deleting branches..."
            for branch in "${branches_to_delete[@]}"; do
                echo "Deleting origin/$branch ..."
                if git push origin --delete "$branch" 2>/dev/null; then
                    echo "✓ Deleted origin/$branch"
                else
                    echo "✗ Failed to delete origin/$branch"
                fi
            done
            ;;
        *)
            echo "Deletion cancelled."
            ;;
    esac
}
