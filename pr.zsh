## pr opens the current pr, if in repo
pr() {
  # Check for help flag
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    cat << 'EOF'
Usage: pr [OPTIONS]

Open the current branch's pull request in your browser.
If no PR exists, opens GitHub's compare page to create one.

Options:
  -h, --help    Show this help message

Behavior:
  - Must be run inside a git repository
  - Uses the 'origin' remote URL
  - Opens a compare URL for the current branch
  - Automatically converts SSH URLs to HTTPS

Examples:
  $ pr
  # Opens: https://github.com/user/repo/compare/feature-branch?expand=1

  $ git checkout feature/helix/LOVE-123-fix-bug
  $ pr
  # Opens: https://github.com/user/repo/compare/feature/helix/LOVE-123-fix-bug?expand=1

  $ pr
  Not inside a git repository.
  # Error: not in a git repo

Notes:
  - Works with both SSH and HTTPS remote URLs
  - Opens in your default browser using the 'open' command
  - Branch name is automatically URL-encoded by the browser

EOF
    return 0
  fi

  # Ensure we're inside a Git repo
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Not inside a git repository."
    return 1
  fi

  # Remote URL (e.g. git@github.com:user/repo.git or https://github.com/user/repo.git)
  remote=$(git config --get remote.origin.url)

  if [[ -z "$remote" ]]; then
    echo "No remote 'origin' found."
    return 1
  fi

  # Convert SSH URLs to HTTPS URLs
  remote_https=$remote
  remote_https=${remote_https/git@github.com:/https://github.com/}
  remote_https=${remote_https%.git}

  # Current branch
  branch=$(git rev-parse --abbrev-ref HEAD)

  # Construct compare URL
  url="$remote_https/compare/$branch?expand=1"

  # Open in browser
  open "$url"
}
