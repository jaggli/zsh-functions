stashes() {
    # -----------------------------
    # 0. Check for help flag
    # -----------------------------
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        cat << 'EOF'
Usage: stashes [OPTIONS]

Interactive menu to manage git stashes.
Choose between unstashing (applying) or cleaning up (deleting) stashes.

Options:
  -h, --help    Show this help message

Features:
  - Interactive action selection
  - Unstash: Apply a stash and optionally drop it
  - Clean up: Delete stashes without applying them

Navigation:
  ↑/↓ or j/k    Navigate through options
  Enter         Select action
  ESC/Ctrl-C    Abort

Examples:
  $ stashes
  Stash action >
  > 💾 Stash - Create a new stash with a name
    📦 Unstash - Apply and optionally drop a stash
    🗑️  Clean up - Delete stashes without applying
    ✖ Abort

  # Select "Stash" and press Enter
  Stash name: work in progress
  ✓ Created stash: work in progress

  ---

  $ stashes
  Stash action >
  > 💾 Stash - Create a new stash with a name
    📦 Unstash - Apply and optionally drop a stash
    🗑️  Clean up - Delete stashes without applying
    ✖ Abort

  # Select "Unstash" and press Enter
  Available stashes >
  > stash@{0}: WIP on main: 1a2b3c4 commit message
    stash@{1}: WIP on feature: 5d6e7f8 another commit
    ✖ Abort

  Applying stash@{0} ...
  Drop stash@{0} now? (y/N): y

  ---

  $ stashes
  Stash action >
  > 📦 Unstash - Apply and optionally drop a stash
    🗑️  Clean up - Delete stashes without applying
    ✖ Abort

  # Select "Clean up" and press Enter
  Available stashes >
  > stash@{0}: WIP on main: 1a2b3c4 commit message
    stash@{1}: WIP on feature: 5d6e7f8 another commit
    ✖ Abort

  # Use TAB to select multiple stashes
  Selected stashes to delete:
    - stash@{0}
    - stash@{1}

  Delete these 2 stash(es)? (y/N): y

Actions:
  💾 Stash       - Create a new stash with all changes
  📦 Unstash     - Apply stash to working directory, optionally drop it
  🗑️  Clean up   - Delete stashes without applying (supports multi-select)

Requirements:
  - fzf (fuzzy finder) - will prompt to install if not found
  - stash, unstash and cleanstash functions must be available

See also:
  stash -h       Show help for stash command
  unstash -h     Show help for unstash command
  cleanstash -h  Show help for cleanstash command

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
    # 2. Build action menu
    # -----------------------------
    local stash_option="💾 Stash - Create a new stash with a name"
    local unstash_option="📦 Unstash - Apply and optionally drop a stash"
    local cleanup_option="🗑️  Clean up - Delete stashes without applying"
    local abort_label="✖ Abort"

    local choices
    choices=$(
        {
            echo "$stash_option"
            echo "$unstash_option"
            echo "$cleanup_option"
            echo "$abort_label"
        }
    )

    # -----------------------------
    # 3. Run fzf menu
    # -----------------------------
    local selection
    selection=$(printf "%s\n" "$choices" \
        | fzf --prompt="Stash action > " \
              -i \
              --reverse \
              --border \
              --header="What would you like to do?" \
              --no-multi \
              --bind=enter:accept
    )

    # ESC or Ctrl-C
    if [[ -z "$selection" ]]; then
        echo "Aborted."
        return 1
    fi

    # -----------------------------
    # 4. Execute based on selection
    # -----------------------------
    case "$selection" in
        "$stash_option")
            stash
            ;;
        "$unstash_option")
            unstash
            ;;
        "$cleanup_option")
            cleanstash
            ;;
        "$abort_label")
            echo "Aborted."
            return 1
            ;;
        *)
            echo "Unknown selection."
            return 1
            ;;
    esac
}
