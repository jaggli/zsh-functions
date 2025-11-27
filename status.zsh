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
  - Revert changes to discard modifications

File Status Indicators:
  M   Modified (unstaged)
  A   Added (staged)
  D   Deleted
  R   Renamed
  ??  Untracked

Navigation:
  ↑/↓ or j/k    Navigate through files
  TAB           Select/deselect file (multi-select)
  Enter         Toggle staging for selected file(s)
  Ctrl-R        Revert changes (discard modifications)
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
    local selected_output
    selected_output=$(
      echo "$status_output" | fzf \
        --height=100% \
        -i \
        --reverse \
        --border \
        --prompt="Git Status > " \
        --header="[Enter] toggle stage | [Ctrl-r] revert | [TAB] multi-select | [ESC] exit" \
        --multi \
        --ansi \
        --expect=ctrl-r \
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

    # Parse the key pressed and the selected files
    local key_pressed
    key_pressed=$(echo "$selected_output" | head -1)
    
    # Get all selected files (skip first line which is the key)
    local selected_files=()
    while IFS= read -r line; do
      [[ -n "$line" ]] && selected_files+=("$line")
    done <<< "$(echo "$selected_output" | tail -n +2)"

    # Exit if no selection (ESC or Ctrl-C)
    if [[ ${#selected_files[@]} -eq 0 ]]; then
      echo "Exited status viewer."
      break
    fi

    # -----------------------------
    # 4. Handle action based on key pressed
    # -----------------------------
    if [[ "$key_pressed" == "ctrl-r" ]]; then
      # Revert changes for all selected files
      local files_to_revert=()
      local untracked_to_delete=()
      
      for selected_file in "${selected_files[@]}"; do
        local staging_status=$(echo "$selected_file" | awk '{print $1}')
        local filename=$(echo "$selected_file" | awk '{print $NF}')
        
        if [[ "$staging_status" == "[UNTRACKED]" ]]; then
          untracked_to_delete+=("$filename")
        else
          files_to_revert+=("$filename")
        fi
      done
      
      # Handle untracked files
      if [[ ${#untracked_to_delete[@]} -gt 0 ]]; then
        echo "Untracked files to delete:"
        for f in "${untracked_to_delete[@]}"; do
          echo "  - $f"
        done
        read "confirm?Delete these ${#untracked_to_delete[@]} untracked file(s)? (y/N): "
        case "$confirm" in
          [yY][eE][sS]|[yY])
            for f in "${untracked_to_delete[@]}"; do
              rm "$f"
              echo "✓ Deleted: $f"
            done
            ;;
          *)
            echo "Skipped deletion."
            ;;
        esac
      fi
      
      # Handle tracked files
      if [[ ${#files_to_revert[@]} -gt 0 ]]; then
        echo "Files to revert:"
        for f in "${files_to_revert[@]}"; do
          echo "  - $f"
        done
        read "confirm?Revert changes in these ${#files_to_revert[@]} file(s)? This cannot be undone. (y/N): "
        case "$confirm" in
          [yY][eE][sS]|[yY])
            for f in "${files_to_revert[@]}"; do
              git reset HEAD "$f" 2>/dev/null
              git checkout -- "$f"
              echo "✓ Reverted: $f"
            done
            ;;
          *)
            echo "Skipped revert."
            ;;
        esac
      fi
    else
      # Toggle staging for all selected files
      for selected_file in "${selected_files[@]}"; do
        local staging_status=$(echo "$selected_file" | awk '{print $1}')
        local filename=$(echo "$selected_file" | awk '{print $NF}')

        if [[ "$staging_status" == "[STAGED]" ]]; then
          echo "Unstaging: $filename"
          git reset HEAD "$filename"
        elif [[ "$staging_status" == "[UNSTAGED]" ]]; then
          echo "Staging: $filename"
          git add "$filename"
        elif [[ "$staging_status" == "[UNTRACKED]" ]]; then
          echo "Adding: $filename"
          git add "$filename"
        fi
      done
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

    # Check if everything is staged (no unstaged or untracked files)
    if ! echo "$status_output" | grep -q '\[UNSTAGED\]\|\[UNTRACKED\]'; then
      echo "✓ All changes are staged."
      echo
      echo "Staged files:"
      
      # Get list of staged files and display in tree-like structure
      git diff --cached --name-only | while IFS= read -r file; do
        # Get the directory and filename
        dir=$(dirname "$file")
        base=$(basename "$file")
        
        # Simple tree-like output with indentation
        if [[ "$dir" == "." ]]; then
          echo "  └─ $base"
        else
          echo "  └─ $file"
        fi
      done
      
      echo
      read "ans?Would you like to commit and push these changes? (Y/n): "
      case "$ans" in
        [nN][oO]|[nN])
          echo "Skipped commit and push."
          ;;
        *)
          # Use the commit function with push flag
          commit -p
          ;;
      esac
      break
    fi
  done
}
