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

# Check if shellcheck is available
if ! command -v shellcheck >/dev/null 2>&1; then
    panic "shellcheck is not installed."
fi

# Check if git is available
if ! command -v git >/dev/null 2>&1; then
    panic "git is not installed."
fi

# Get all shell scripts in the repository (store in array to preserve filenames safely).
mapfile -t shell_files < <(git ls-files -- '*.sh')

if [ "${#shell_files[@]}" -eq 0 ]; then
    printf '%s\n' "No shell scripts found in the repository."
    exit 0
fi

printf '%s\n' "Fixing shell script linting issues..."

# First pass: generate diff for auto-fixable issues.
diff_output=$(shellcheck -f diff -S warning "${shell_files[@]}" 2>/dev/null || true)

if [ -n "$diff_output" ]; then
    if printf '%s' "$diff_output" | git apply --allow-empty 2>/dev/null; then
        printf '%s\n' "Applied auto-fixable shell script linting changes."
    else
        panic "Failed to apply some auto-fixable shell script changes."
    fi
else
    printf '%s\n' "No auto-fixable shell script issues found."
fi

# Second pass: run shellcheck normally to detect any remaining issues (including non-fixable).
if shellcheck -S warning "${shell_files[@]}" >/dev/null 2>&1; then
    if [ -n "$diff_output" ]; then
        printf '%s\n' "All shell script issues resolved after auto-fixes."
    else
        printf '%s\n' "No shell script issues found."
    fi
    exit 0
else
    if [ -n "$diff_output" ]; then
        panic "Error: remaining shell script issues after applying fixes."
    else
        panic "Error: shell script issues detected (none auto-fixable)."
    fi
fi
