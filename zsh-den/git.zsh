#!/usr/bin/env zsh

# My own little set of git shortcuts
alias gnewbranch="git switch main && git pull origin main && git switch -c"
alias gpbranch="git push -u origin HEAD"
alias gac="git add . && git commit -m"
alias gl="git log --oneline"
alias gsw="git switch"
alias gs="git status"
alias gc="git commit"
alias gp="git push"
alias ga="git add"
alias g="git"

gpr:create() {
    local branch_name
    if [ -n "$1" ]; then
        branch_name="$1"
    else
        branch_name=$(git symbolic-ref --short HEAD 2>/dev/null)
    fi
    if [ -z "$branch_name" ]; then
        echo "Error: Could not determine branch name. Are you in a git repo?" >&2
        return 1
    fi
    echo "Pushing branch '$branch_name' and creating PR against 'main'..."
    # Ensure branch is pushed before creating PR
    git push -u origin "$branch_name" && \
        gh pr create --base main --head "$branch_name" --fill
}

gpr:merge() {
    local branch_name
    if [ -n "$1" ]; then
        branch_name="$1"
    else
        branch_name=$(git symbolic-ref --short HEAD 2>/dev/null)
    fi
    if [ -z "$branch_name" ]; then
        echo "Error: Could not determine branch name. Are you in a git repo?" >&2
        return 1
    fi
    echo "Merging PR for branch '$branch_name' with --merge and --delete-branch..."
    gh pr merge "$branch_name" --merge --delete-branch
}

gsync() {
    local current_branch
    current_branch=$(git symbolic-ref --short HEAD 2>/dev/null)

    if [ -z "$current_branch" ]; then
        echo "Error: Could not determine current branch. Are you in a git repository?" >&2
        return 1
    fi

    if [ "$current_branch" = "main" ] || [ "$current_branch" = "master" ]; then # Added master for commonality
        echo "Error: Currently on '$current_branch' branch. 'gsync' is intended to clean up feature branches." >&2
        echo "If you only want to pull $current_branch and prune, use 'git pull origin $current_branch && git fetch --prune'." >&2
        return 1
    fi

    echo "Current branch is '$current_branch'."
    echo "Switching to 'main', pulling, deleting local branch '$current_branch', and pruning..."

    if git switch main && \
        git pull origin main && \
        git branch -d "$current_branch" && \
        git fetch --prune; then
        echo "gsync completed successfully for $current_branch."
    else
        echo "Error during gsync operation. Please check the output above." >&2
        return 1
    fi
}

git-work-account() {
    git config user.name 'juan-lsource' && git config user.email 'juan.bautista@logicsource.com'
    git config --get user.name
    git config --get user.email
}
