# Select and switch to a branch using fzf
switch() {
  # -----------------------------
  # 0. Check for help flag
  # -----------------------------
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    cat << 'EOF'
Usage: switch [FILTER...]

Select a git branch using fzf and switch to it.

Arguments:
  FILTER...     Optional search filter words to pre-fill fzf (joined with spaces)

Options:
  -h, --help    Show this help message

Behavior:
  - Lists both local and remote branches
  - Uses fzf for interactive selection
  - Automatically switches to the selected branch
  - For remote branches, creates a local tracking branch if needed
  - Current branch is highlighted with an asterisk (*)

Examples:
  $ switch
  # Opens fzf with list of branches, select one to switch

  $ switch captcha
  # Opens fzf with 'captcha' pre-filled as filter

  $ switch LOVE-123
  # Opens fzf filtering for branches containing 'LOVE-123'

  $ switch update figma guidelines
  # Opens fzf with 'update figma guidelines' pre-filled as filter

Requirements:
  - Must be in a git repository
  - fzf must be installed

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
  # 2. Get current branch and filter
  # -----------------------------
  local current_branch
  current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  
  local filter="$*"

  # -----------------------------
  # 3. List branches and select with fzf
  # -----------------------------
  local selected_branch
  selected_branch=$(
    {
      # List local branches
      git branch --format='%(refname:short)' | sed 's/^/local: /'
      # Spacer
      echo "─────────────────────────────"
      # List remote branches, excluding HEAD and origin/origin
      git branch -r --format='%(refname:short)' | grep -v 'HEAD' | grep -v '^origin$' | sed 's/^/remote: /'
    } | fzf \
      --height=40% \
      --reverse \
      --border \
      --prompt="Select branch: " \
      --query="$filter" \
      -i \
      --preview="branch=\$(echo {} | sed 's/^[^:]*: //'); if [[ \"\$branch\" == *───* ]]; then echo 'Spacer - not selectable'; else git log --color=always -n 1 --format='%C(bold cyan)Author:%C(reset) %an%n%C(bold cyan)Date:%C(reset) %ar (%ad)%n%C(bold cyan)Message:%C(reset) %s%n' --date=format:'%Y-%m-%d %H:%M' \"\$branch\" 2>/dev/null && echo && git log --oneline --color=always -n 10 \"\$branch\" 2>/dev/null; fi" \
      --preview-window=right:50% \
      --header="Current: $current_branch"
  )

  # -----------------------------
  # 4. Handle selection
  # -----------------------------
  if [[ -z "$selected_branch" ]]; then
    echo "No branch selected."
    return 0
  fi

  # Ignore spacer selection
  if [[ "$selected_branch" == *───* ]]; then
    echo "Invalid selection."
    return 0
  fi

  # Extract branch type and name
  local branch_type="${selected_branch%%:*}"
  local branch_name="${selected_branch#*: }"

  # -----------------------------
  # 5. Switch to branch
  # -----------------------------
  if [[ "$branch_type" == "local" ]]; then
    # Switch to local branch
    echo "Switching to local branch: $branch_name"
    git checkout "$branch_name"
  else
    # Handle remote branch
    local local_branch="${branch_name#*/}"  # Remove origin/ prefix
    
    # Check if local branch already exists
    if git show-ref --verify --quiet "refs/heads/$local_branch"; then
      echo "Switching to existing local branch: $local_branch"
      git checkout "$local_branch"
    else
      echo "Creating local tracking branch: $local_branch (tracking $branch_name)"
      git checkout -b "$local_branch" --track "$branch_name"
    fi
  fi

  if [[ $? -eq 0 ]]; then
    echo "✓ Successfully switched to branch: $(git rev-parse --abbrev-ref HEAD)"
  else
    echo "✗ Failed to switch branch."
    return 1
  fi
}
