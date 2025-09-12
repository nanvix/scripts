#!/bin/bash

# Copyright(c) The Maintainers of Nanvix.
# Licensed under the MIT License.

set -euo pipefail

#==================================================================================================
# Imports
#==================================================================================================

# Source utility functions.
source "$(dirname "${0}")/utils.sh"

#==================================================================================================
# Main Script
#==================================================================================================

# Check if codespell is available
if ! command -v codespell >/dev/null 2>&1; then
    panic "codespell is not installed."
fi

# Check if git is available
if ! command -v git >/dev/null 2>&1; then
    panic "git is not installed."
fi

# Get text-like files in the repository (store in array to preserve filenames safely).
# We limit to common text file extensions to avoid touching binary assets.
mapfile -t text_files < <(git ls-files -- '*.md' '*.txt' '*.rst' '*.py' '*.sh' '*.c' '*.h' '*.cpp' '*.hpp' '*.js' '*.json' '*.yaml' '*.yml' '*.html' '*.css' '*.toml' '*.ini' '*.cfg' '*.tex' '*.go' '*.rs' '*.java' '*.xml' '*.sql' 2>/dev/null)

if [ "${#text_files[@]}" -eq 0 ]; then
    printf '%s\n' "No text files found in the repository."
    exit 0
fi

printf '%s\n' "Fixing text file spelling issues..."

# First pass: attempt to auto-fix spelling issues in-place.
# codespell's -w flag writes fixes directly to files.
# We capture stderr/stdout but don't fail the script if codespell returns non-zero.
codespell -w "${text_files[@]}" 2>/dev/null || true

# Detect which files were modified by codespell (if any).
modified_files=$(git ls-files -m)

if [ -n "$modified_files" ]; then
    printf '%s\n' "Applied auto-fixable spelling changes."
else
    printf '%s\n' "No auto-fixable spelling issues found."
fi

# Second pass: run codespell normally to detect any remaining issues (non-auto-fixable).
# Capture output so we can decide whether to fail or succeed.
remaining_issues=$(codespell --quiet "${text_files[@]}" 2>/dev/null || true)

if [ -z "$remaining_issues" ]; then
    if [ -n "$modified_files" ]; then
        printf '%s\n' "All spelling issues resolved after auto-fixes."
    else
        printf '%s\n' "No spelling issues found."
    fi
    exit 0
else
    if [ -n "$modified_files" ]; then
        panic "Error: remaining spelling issues after applying fixes.\n$remaining_issues"
    else
        panic "Error: spelling issues detected (none auto-fixable).\n$remaining_issues"
    fi
fi
