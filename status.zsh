# Show git status with fzf file selector and diff preview
status() {
  # -----------------------------
  # 0. Check for help flag
  # -----------------------------
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    cat << 'EOF'
Usage: status [OPTIONS]

Interactive git status viewer with fzf.
Browse uncommitted changes and view diffs in preview pane.

Options:
  -h, --help    Show this help message

Features:
  - Lists all modified, staged, and untracked files
  - Preview shows git diff for each file
  - Color-coded file status indicators
  - Supports both staged and unstaged changes

File Status Indicators:
  M   Modified (unstaged)
  A   Added (staged)
  D   Deleted
  R   Renamed
  ??  Untracked

Navigation:
  ↑/↓ or j/k    Navigate through files
  Enter         Exit and show selected file
  ESC/Ctrl-C    Exit

Examples:
  $ status
  Git Status >
  > M  src/app.js
    A  src/new-feature.js
    ?? temp.txt
    M  README.md

  # Preview shows diff of selected file
  # Navigate with arrow keys or j/k

Requirements:
  - Must be in a git repository
  - fzf (fuzzy finder) - will prompt to install if not found

Notes:
  - Staged changes show diff with --cached
  - Unstaged changes show working tree diff
  - Untracked files show file contents
  - Empty status means working tree is clean

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
  # 2. Get git status and format with staging info
  # -----------------------------
  local status_output
  status_output=$(git status --short | awk '{
    index_status = substr($0, 1, 1);
    work_status = substr($0, 2, 1);
    file = substr($0, 4);
    
    # Determine staging status
    if (index_status ~ /[MADRC]/) {
      staged = "[STAGED]";
    } else if (work_status == "?" || index_status == "?") {
      staged = "[UNTRACKED]";
    } else {
      staged = "[UNSTAGED]";
    }
    
    printf "%-12s %s %s\n", staged, substr($0, 1, 2), file;
  }')

  if [[ -z "$status_output" ]]; then
    echo "Working tree clean - no changes to display."
    return 0
  fi

  # -----------------------------
  # 3. Run fzf with diff preview in a loop
  # -----------------------------
  while true; do
    local selected_file
    selected_file=$(
      echo "$status_output" | fzf \
        --height=100% \
        --reverse \
        --border \
        --prompt="Git Status > " \
        --header="Enter: toggle stage | ESC: exit" \
        --no-multi \
        --ansi \
        --preview='
          file=$(echo {} | awk "{print \$NF}");
          file_status=$(echo {} | awk "{print \$2}");
          
          # Show diff based on file status
          if [[ "$file_status" == "??" ]]; then
            # Untracked file - show contents
            echo "=== UNTRACKED FILE ===";
            echo;
            bat --color=always --style=numbers "$file" 2>/dev/null || cat "$file" 2>/dev/null || echo "Cannot preview file";
          elif [[ "$file_status" =~ ^[MAC] ]]; then
            # Staged file - show cached diff
            echo "=== STAGED CHANGES ===";
            echo;
            git diff --cached --color=always "$file" 2>/dev/null | delta 2>/dev/null || git diff --cached --color=always "$file" 2>/dev/null;
            if git diff --color=always "$file" 2>/dev/null | grep -q .; then
              echo;
              echo "=== UNSTAGED CHANGES ===";
              echo;
              git diff --color=always "$file" 2>/dev/null | delta 2>/dev/null || git diff --color=always "$file" 2>/dev/null;
            fi
          else
            # Unstaged changes
            echo "=== UNSTAGED CHANGES ===";
            echo;
            git diff --color=always "$file" 2>/dev/null | delta 2>/dev/null || git diff --color=always "$file" 2>/dev/null;
          fi
        ' \
        --preview-window=right:60%
    )

    # Exit if no selection (ESC or Ctrl-C)
    if [[ -z "$selected_file" ]]; then
      echo "Exited status viewer."
      break
    fi

    # -----------------------------
    # 4. Toggle staging for selected file
    # -----------------------------
    local staging_status
    staging_status=$(echo "$selected_file" | awk '{print $1}')
    local filename
    filename=$(echo "$selected_file" | awk '{print $NF}')

    if [[ "$staging_status" == "[STAGED]" ]]; then
      # Unstage the file
      echo "Unstaging: $filename"
      git reset HEAD "$filename"
    elif [[ "$staging_status" == "[UNSTAGED]" ]]; then
      # Stage the file
      echo "Staging: $filename"
      git add "$filename"
    elif [[ "$staging_status" == "[UNTRACKED]" ]]; then
      # Add untracked file
      echo "Adding: $filename"
      git add "$filename"
    fi

    # Refresh status output
    status_output=$(git status --short | awk '{
      index_status = substr($0, 1, 1);
      work_status = substr($0, 2, 1);
      file = substr($0, 4);
      
      # Determine staging status
      if (index_status ~ /[MADRC]/) {
        staged = "[STAGED]";
      } else if (work_status == "?" || index_status == "?") {
        staged = "[UNTRACKED]";
      } else {
        staged = "[UNSTAGED]";
      }
      
      printf "%-12s %s %s\n", staged, substr($0, 1, 2), file;
    }')

    # Check if working tree is now clean
    if [[ -z "$status_output" ]]; then
      echo "✓ Working tree is now clean - all changes staged or reverted."
      break
    fi
  done
}
