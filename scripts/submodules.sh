#!/usr/bin/env bash
# Initialize/update submodules and leave each one on the branch recorded in
# .gitmodules, instead of the detached HEAD that `git submodule update` gives.
set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

git submodule update --init --recursive

git submodule foreach --quiet --recursive '
    branch=$(git config -f "$toplevel/.gitmodules" "submodule.$name.branch" || true)
    if [ -z "$branch" ]; then
        echo "$displaypath: no branch in .gitmodules, leaving at $(git rev-parse --short HEAD)"
        exit 0
    fi

    pinned=$(git rev-parse HEAD)

    if git show-ref --quiet --verify "refs/heads/$branch"; then
        git checkout --quiet "$branch"
    else
        # Create the branch at the commit the superproject pins, so we never
        # silently jump to a newer upstream tip, then track origin.
        git checkout --quiet -b "$branch" "$pinned"
        git branch --quiet --set-upstream-to "origin/$branch" "$branch" 2>/dev/null || true
    fi

    if [ "$(git rev-parse HEAD)" != "$pinned" ]; then
        echo "$displaypath: warning: local $branch is at $(git rev-parse --short HEAD), superproject pins $(git rev-parse --short "$pinned")"
    fi

    echo "$displaypath: on $branch"
'
