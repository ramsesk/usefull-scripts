#!/bin/bash

# Variables: GitHub Token, Repository owner, Repository name
GITHUB_TOKEN="YOUR_TOKEN"
REPO_OWNER="YOUR_REPO_OWNER"
REPO_NAME="YOUR_REPO_NAME"

# Function to check for API errors
check_for_api_error() {
  local response=$1
  if echo "$response" | jq -e .message >/dev/null 2>&1; then
    echo "GitHub API Error: $(echo "$response" | jq -r .message)"
    exit 1
  fi
}

# Fetch all active branches from GitHub (only the branch names)
echo "Fetching all active branches..."
ACTIVE_BRANCHES=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/branches?per_page=100")

# Check for API errors in the active branches response
check_for_api_error "$ACTIVE_BRANCHES"

# Parse active branches into a list
ACTIVE_BRANCHES=$(echo "$ACTIVE_BRANCHES" | jq -r '.[].name')

# Fetch closed PRs (first 100, add pagination handling for larger repos)
echo "Fetching closed pull requests..."
PR_DATA=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/pulls?state=closed&per_page=100")

# Check for API errors in the PR response
check_for_api_error "$PR_DATA"

# Iterate over each PR and check if the branch is still active
echo "$PR_DATA" | jq -r '.[] | {pr_number: .number, branch_name: .head.ref, commit_hash: .head.sha} | "\(.pr_number) \(.branch_name) \(.commit_hash)"' | \
while read pr_number branch_name commit_hash; do
    # echo "Checking branch: $branch_name (from PR #$pr_number)"
    
    # Check if the branch is in the active branches list
    if echo "$ACTIVE_BRANCHES" | grep -q "^$branch_name$"; then
        # echo "PR #$pr_number: Branch '$branch_name' still exists."
        : # pass
    else
        echo "PR #$pr_number: Branch '$branch_name' has been deleted (not in active branches)."
        echo "You can recreate it using the following commit hash: $commit_hash"
    fi
    
    # Small delay to avoid hitting the GitHub API rate limit
    sleep 1
done
