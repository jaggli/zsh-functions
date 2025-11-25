# Stage all changes and commit with a message.
# If no commit message argument is given, prompt the user for one.
commit() {
  local should_push=false
  local msg_parts=()

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      -h|--help)
        cat << 'EOF'
Usage: commit [MESSAGE] [OPTIONS]

Stage all changes (git add -A) and commit with a message.

Options:
  -p, --push    Push to origin after successful commit
  -h, --help    Show this help message

Interactive mode (no message):
  $ commit
  Commit message: fix login bug
  [main 1a2b3c4] fix login bug
   1 file changed, 5 insertions(+), 2 deletions(-)

With message argument:
  $ commit implement new feature
  [main 5d6e7f8] implement new feature
   3 files changed, 42 insertions(+), 8 deletions(-)

With push option:
  $ commit update documentation -p
  [main 9a8b7c6] update documentation
   1 file changed, 10 insertions(+), 3 deletions(-)
  Pushing 'main' to origin...
  ✓ Successfully pushed 'main' to origin.

  $ commit -p hotfix: critical bug
  [main 3c2d1e0] hotfix: critical bug
   2 files changed, 15 insertions(+), 5 deletions(-)
  Pushing 'main' to origin...
  ✓ Successfully pushed 'main' to origin.

Examples:
  commit                                    # Interactive mode
  commit add user validation                # Quick commit
  commit refactor auth module --push        # Commit and push
  commit -p update dependencies             # Commit and push (short flag)

EOF
        return 0
        ;;
      -p|--push)
        should_push=true
        shift
        ;;
      -*)
        echo "Unknown option: $1"
        echo "Usage: commit [message] [-p|--push]"
        return 1
        ;;
      *)
        # Collect all non-flag arguments as message parts
        msg_parts+=("$1")
        shift
        ;;
    esac
  done

  # Join message parts with spaces
  local msg="${msg_parts[*]}"

  # If no commit message was provided...
  if [ -z "$msg" ]; then
    # Prompt the user for a commit message (no newline, no extra spaces)
    read "msg?Commit message: "
  fi

  # Check if there are staged changes
  local has_staged
  has_staged=$(git diff --cached --name-only)
  
  local has_unstaged
  has_unstaged=$(git diff --name-only)

  # If there are both staged and unstaged changes, ask what to commit
  if [[ -n "$has_staged" && -n "$has_unstaged" ]]; then
    echo
    echo "You have both staged and unstaged changes."
    echo
    read "commit_choice?Commit [s]taged only, or [a]ll changes? (s/a): "
    
    case "$commit_choice" in
      [sS])
        # Commit only staged changes
        echo "Committing staged changes only..."
        git commit -m "$msg"
        ;;
      [aA]|*)
        # Stage all and commit
        echo "Staging all changes and committing..."
        git add -A && git commit -m "$msg"
        ;;
    esac
  elif [[ -n "$has_staged" ]]; then
    # Only staged changes exist
    echo "Committing staged changes..."
    git commit -m "$msg"
  else
    # No staged changes, stage all and commit
    git add -A && git commit -m "$msg"
  fi

  # Push if requested and commit was successful
  if [[ $? -eq 0 && "$should_push" == true ]]; then
    current_branch=$(git rev-parse --abbrev-ref HEAD)
    echo "Pushing '$current_branch' to origin..."
    git push origin "$current_branch"
    if [[ $? -eq 0 ]]; then
      echo "✓ Successfully pushed '$current_branch' to origin."
    else
      echo "⚠ Failed to push '$current_branch' to origin."
      return 1
    fi
  fi
}
