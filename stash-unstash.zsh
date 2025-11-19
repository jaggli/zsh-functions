unstash() {
    # -----------------------------
    # 0. Check for help flag
    # -----------------------------
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        cat << 'EOF'
Usage: unstash [OPTIONS]

Apply a git stash to your working directory with optional removal.
Interactive fuzzy finder (fzf) with preview support.

Options:
  -h, --help    Show this help message

Features:
  - Single-select stash picker
  - Preview stash contents before applying
  - Apply stash to working directory
  - Optional confirmation to drop stash after applying

Navigation:
  ↑/↓ or j/k    Navigate through stashes
  Enter         Select and apply stash
  ESC/Ctrl-C    Abort

Examples:
  $ unstash
  Available stashes >
  > stash@{0}: WIP on main: 1a2b3c4 commit message
    stash@{1}: WIP on feature: 5d6e7f8 another commit
    stash@{2}: On dev: 9a8b7c6 old work
    ✖ Abort

  # Navigate to desired stash and press Enter
  
  Applying stash@{1} ...
  On branch main
  Changes not staged for commit:
    modified:   src/app.js

  Drop stash@{1} now? (y/N): y
  Dropping stash@{1} ...
  Dropped stash@{1} (5d6e7f8abcd...)

Workflow:
  1. Select a stash from the list
  2. Stash is applied to your working directory
  3. Choose whether to drop (delete) the stash or keep it

Requirements:
  - fzf (fuzzy finder) - will prompt to install if not found
  - git stash list with at least one stash

Notes:
  - Uses 'git stash apply' to preserve the stash initially
  - Stash is only dropped if you confirm after successful apply
  - Preview shows the full diff of the selected stash
  - If apply fails, the stash is automatically kept

EOF
        return 0
    fi

    # -----------------------------
    # 1. Check for fzf
    # -----------------------------
    if ! command -v fzf >/dev/null 2>&1; then
        echo "fzf is not installed."

        # Ask whether to install with Homebrew
        read "ans?Install fzf with Homebrew? (y/N): "
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
    # 3. Run fzf full-screen picker with preview
    # -----------------------------
    local selection
    selection=$(printf "%s\n" "$choices" \
        | fzf --prompt="Available stashes > " \
              --reverse \
              --border \
              --header="Select a stash to apply" \
              --no-multi \
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
    if [[ "$selection" == "$abort_label" ]]; then
        echo "Aborted."
        return 1
    fi

    # -----------------------------
    # 4. Extract stash ID safely
    # -----------------------------
    local stash_id
    stash_id=$(echo "$selection" | grep -o 'stash@{[0-9]\+}')

    if [[ -z "$stash_id" ]]; then
        echo "Error: Could not determine stash ID."
        return 1
    fi

    # -----------------------------
    # 5. Apply the stash
    # -----------------------------
    echo "Applying $stash_id ..."
    if ! git stash apply "$stash_id"; then
        echo "Apply failed, kept stash."
        return 1
    fi

    # -----------------------------
    # 6. Confirm before dropping
    # -----------------------------
    echo
    read "drop_ans?Drop $stash_id now? (y/N): "
    case "$drop_ans" in
        [yY][eE][sS]|[yY])
            echo "Dropping $stash_id ..."
            git stash drop "$stash_id"
            ;;
        *)
            echo "Stash NOT dropped."
            ;;
    esac
}
