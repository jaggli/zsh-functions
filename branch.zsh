branch() {
    # -----------------------------
    # 0. Check for help flag
    # -----------------------------
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        cat << 'EOF'
Usage: branch [OPTIONS]

Interactive menu to manage git branches.
Choose between creating, switching, or updating branches.

Options:
  -h, --help    Show this help message

Features:
  - Interactive action selection
  - Create: Create a new branch with Jira issue parsing
  - Switch: Switch between branches with fzf selector
  - Update: Update current branch with latest main/master

Navigation:
  ↑/↓ or j/k    Navigate through options
  Enter         Select action
  ESC/Ctrl-C    Abort

Examples:
  $ branch
  Branch action >
  > 🌿 Create - Create a new feature branch
    🔀 Switch - Switch to another branch
    ⬆️  Update - Update current branch with main/master
    ✖ Abort

  # Select "Create" and press Enter
  Enter Jira link (e.g., https://jira.company.com/browse/PROJ-123):
  > PROJ-123
  Parsed issue number: PROJ-123

  Enter branch title (will be converted to lowercase with dashes):
  > add new feature

  Branch name: feature/PROJ-123-add-new-feature
  Updating 'main' from origin...
  ✓ 'main' is up to date.
  ✓ Successfully created and switched to branch: feature/PROJ-123-add-new-feature (from main)

  ---

  $ branch
  Branch action >
  > 🌿 Create - Create a new feature branch
    🔀 Switch - Switch to another branch
    ⬆️  Update - Update current branch with main/master
    ✖ Abort

  # Select "Switch" and press Enter
  Select branch: 
  Current: main
  > local: main
    local: feature/PROJ-123-add-new-feature
    remote: origin/develop

  ---

  $ branch
  Branch action >
  > 🌿 Create - Create a new feature branch
    🔀 Switch - Switch to another branch
    ⬆️  Update - Update current branch with main/master
    ✖ Abort

  # Select "Update" and press Enter
  Fetching latest 'main' from origin...
  Merging updated 'main' into 'feature/PROJ-123-add-new-feature'...
  ✓ 'feature/PROJ-123-add-new-feature' is now up-to-date with 'main'.

Actions:
  🌿 Create  - Create a new feature branch with Jira parsing
  🔀 Switch  - Switch to another branch using fzf
  ⬆️  Update - Update current branch with latest main/master

Requirements:
  - fzf (fuzzy finder) - will prompt to install if not found
  - create, switch, and update functions must be available

See also:
  create -h    Show help for create command
  switch -h    Show help for switch command
  update -h    Show help for update command

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
    # 2. Build action menu
    # -----------------------------
    local create_option="🌿 Create - Create a new feature branch"
    local switch_option="🔀 Switch - Switch to another branch"
    local update_option="⬆️  Update - Update current branch with main/master"
    local abort_label="✖ Abort"

    local choices
    choices=$(
        {
            echo "$create_option"
            echo "$switch_option"
            echo "$update_option"
            echo "$abort_label"
        }
    )

    # -----------------------------
    # 3. Run fzf menu
    # -----------------------------
    local selection
    selection=$(printf "%s\n" "$choices" \
        | fzf --prompt="Branch action > " \
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
        "$create_option")
            create
            ;;
        "$switch_option")
            switch
            ;;
        "$update_option")
            update
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
