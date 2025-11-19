cleanstash() {
    # -----------------------------
    # 0. Check for help flag
    # -----------------------------
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        cat << 'EOF'
Usage: cleanstash [OPTIONS]

Delete git stashes without applying them.
Interactive fuzzy finder (fzf) with preview and multi-select support.

Options:
  -h, --help    Show this help message

Features:
  - Multi-select support (use TAB to select multiple stashes)
  - Preview stash contents before deletion
  - Confirmation prompt before deletion
  - Safe deletion (deletes in reverse order to maintain indices)

Navigation:
  ↑/↓ or j/k    Navigate through stashes
  TAB           Select/deselect stash (multi-select)
  Enter         Confirm selection
  ESC/Ctrl-C    Abort

Examples:
  $ cleanstash
  Available stashes >
  > stash@{0}: WIP on main: 1a2b3c4 commit message
    stash@{1}: WIP on feature: 5d6e7f8 another commit
    stash@{2}: On dev: 9a8b7c6 old work
    ✖ Abort

  # Select stash@{0} and stash@{2} using TAB, then press Enter
  
  Selected stashes to delete:
    - stash@{0}
    - stash@{2}

  Delete these 2 stash(es)? (y/N): y
  Deleting stashes...
  Dropping stash@{2} ...
  ✓ Deleted stash@{2}
  Dropping stash@{0} ...
  ✓ Deleted stash@{0}

Requirements:
  - fzf (fuzzy finder) - will prompt to install if not found
  - git stash list with at least one stash

Notes:
  - Stashes are deleted in reverse order to prevent index shifts
  - Preview shows the full diff of the selected stash
  - No changes are applied to your working directory

EOF
        return 0
    fi

    # -----------------------------
    # 1. Check for fzf
    # -----------------------------
    if ! command -v fzf >/dev/null 2>&1; then
        echo "fzf is not installed."

        # Ask whether to install with Homebrew
        read -r -p "Install fzf with Homebrew? (y/N): " ans
        case "$ans" in
            [yY][eE][sS]|[yY])
                echo "Installing fzf with brew..."
                if ! command -v brew >/dev/null 2>&1; then
                    echo "Homebrew is not installed. Aborting."
                    return 1
                fi
                brew install fzf || { echo "fzf install failed. Aborting."; return 1; }
                # Optional: install shell integrations automatically
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
    # 2. Build menu entries
    # -----------------------------
    local abort_label="✖ Abort"

    local choices
    choices=$(
        {
            git stash list
            echo "$abort_label"
        }
    )

    # -----------------------------
    # 3. Run fzf full-screen picker with preview (multi-select)
    # -----------------------------
    local selection
    selection=$(printf "%s\n" "$choices" \
        | fzf --prompt="Available stashes > " \
              --reverse \
              --border \
              --header="Select stashes to delete (TAB for multi-select)" \
              --multi \
              --bind=enter:accept \
              --preview='
                    sel=$(echo {} | grep -o "stash@{[0-9]\+}" || true);
                    if [[ -n "$sel" ]]; then
                        git stash show -p "$sel";
                    else
                        echo "No preview";
                    fi
              '
    )

    # ESC or Ctrl-C
    if [[ -z "$selection" ]]; then
        echo "Aborted."
        return 1
    fi

    # Abort option
    if echo "$selection" | grep -q "^$abort_label$"; then
        echo "Aborted."
        return 1
    fi

    # -----------------------------
    # 4. Extract stash IDs safely
    # -----------------------------
    local stash_ids=()
    while IFS= read -r line; do
        local stash_id
        stash_id=$(echo "$line" | grep -o 'stash@{[0-9]\+}')
        if [[ -n "$stash_id" ]]; then
            stash_ids+=("$stash_id")
        fi
    done <<< "$selection"

    if [[ ${#stash_ids[@]} -eq 0 ]]; then
        echo "Error: Could not determine any stash IDs."
        return 1
    fi

    # -----------------------------
    # 5. Confirm before deletion
    # -----------------------------
    echo "Selected stashes to delete:"
    for stash_id in "${stash_ids[@]}"; do
        echo "  - $stash_id"
    done
    echo

    read "confirm_ans?Delete these ${#stash_ids[@]} stash(es)? (y/N): "
    case "$confirm_ans" in
        [yY][eE][sS]|[yY])
            # -----------------------------
            # 6. Delete stashes (in reverse order to maintain indices)
            # -----------------------------
            echo "Deleting stashes..."
            # Sort by stash number in descending order to delete safely
            local sorted_ids=($(printf '%s\n' "${stash_ids[@]}" | sort -t'{' -k2 -rn))
            
            for stash_id in "${sorted_ids[@]}"; do
                echo "Dropping $stash_id ..."
                if git stash drop "$stash_id"; then
                    echo "✓ Deleted $stash_id"
                else
                    echo "✗ Failed to delete $stash_id"
                fi
            done
            ;;
        *)
            echo "Deletion cancelled. No stashes were removed."
            ;;
    esac
}
