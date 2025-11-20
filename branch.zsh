branch() {
    # -----------------------------
    # 0. Check for help flag
    # -----------------------------
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        cat << 'EOF'
Usage: branch [JIRA_LINK] [TITLE...]

Create a new git branch with the pattern: feature/<ISSUE>-<title>

Options:
  -h, --help    Show this help message

Configuration:
  - Branch prefix can be changed by editing the 'ZSH_FUNCTIONS_FEATURE_BRANCH_PREFIX' variable
  - Default: "feature/"

Interactive mode (no arguments):
  $ branch
  Enter Jira link (e.g., https://jira.company.com/browse/PROJ-123):
  > https://jira.company.com/browse/PROJ-123
  Parsed issue number: PROJ-123

  Enter branch title (will be converted to lowercase with dashes):
  > Fix Login Bug
  
  Branch name: feature/PROJ-123-fix-login-bug
  Create this branch? (y/N): y

One-liner mode (with arguments):
  $ branch https://jira.company.com/browse/PROJ-123 fix login bug
  Parsed issue number: PROJ-123
  
  Branch name: feature/PROJ-123-fix-login-bug
  Create this branch? (y/N): y

  $ branch PROJ-456 add user settings
  Parsed issue number: PROJ-456
  
  Branch name: feature/PROJ-456-add-user-settings
  Create this branch? (y/N): y

Examples:
  branch https://jira.company.com/browse/PROJ-123 make some fixes
  branch PROJ-456 implement new feature
  branch https://company.atlassian.net/browse/ABC-789 refactor code

EOF
        return 0
    fi

    # -----------------------------
    # 1. Get Jira link from user (or from arguments)
    # -----------------------------
    local jira_link
    local branch_title
    
    if [[ -n "$1" ]]; then
        # Arguments provided - use one-liner mode
        jira_link="$1"
        shift
        # Join remaining arguments as title
        branch_title="$*"
    else
        # Interactive mode
        echo "Enter Jira link (e.g., https://jira.company.com/browse/PROJ-123):"
        read "jira_link? > "
    fi

    if [[ -z "$jira_link" ]]; then
        echo "Error: No Jira link provided."
        return 1
    fi

    # -----------------------------
    # 2. Parse issue number from Jira link
    # -----------------------------
    local issue_number
    # Match patterns like PROJ-123, ABC-456, etc.
    # Supports both /browse/PROJ-123 and selectedIssue=PROJ-123 formats
    issue_number=$(echo "$jira_link" | grep -o -E '(browse/|selectedIssue=)[A-Z]+-[0-9]+' | grep -o '[A-Z]\+-[0-9]\+' | head -1)

    if [[ -z "$issue_number" ]]; then
        echo "Warning: Could not parse issue number from Jira link. Using NOISSUE."
        issue_number="NOISSUE"
        # If parsing failed and we had arguments, include the first arg in the title
        if [[ -n "$branch_title" ]]; then
            branch_title="$jira_link $branch_title"
        else
            branch_title="$jira_link"
        fi
    else
        echo "Parsed issue number: $issue_number"
    fi
    echo

    # -----------------------------
    # 3. Get branch title from user (if not already provided)
    # -----------------------------
    if [[ -z "$branch_title" ]]; then
        echo "Enter branch title (will be converted to lowercase with dashes):"
        read "branch_title? > "
    fi

    if [[ -z "$branch_title" ]]; then
        echo "Error: No branch title provided."
        return 1
    fi

    # Convert title to lowercase and replace spaces/special chars with dashes
    branch_title=$(echo "$branch_title" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//;s/-$//')

    # -----------------------------
    # 4. Construct branch name
    # -----------------------------
    local branch_prefix="${ZSH_FUNCTIONS_FEATURE_BRANCH_PREFIX:-feature/}"
    local branch_name="${branch_prefix}${issue_number}-${branch_title}"
    
    echo
    echo "Branch name: $branch_name"
    echo

    # -----------------------------
    # 5. Create branch
    # -----------------------------
    echo "Creating branch..."
    if git checkout -b "$branch_name"; then
        echo "✓ Successfully created and switched to branch: $branch_name"
    else
        echo "✗ Failed to create branch."
        return 1
    fi
}
