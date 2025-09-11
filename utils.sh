#!/bin/bash

# Copyright(c) The Maintainers of Nanvix.
# Licensed under the MIT License.

#
# Utility functions.
#

#===================================================================================================
# Include Guard
#===================================================================================================

# If executed directly, abort. This file is intended to be sourced.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    printf '%s\n' "This file is intended to be sourced, not executed." >&2
    exit 1
fi

# Skip this file if already included.
if [[ -n "${__UTILS_SH_INCLUDED:-}" ]]; then
    return
fi
readonly __UTILS_SH_INCLUDED=1

#==================================================================================================
# Logging
#==================================================================================================

# Colors
readonly RED='\033[0;31m'    # Red
readonly GREEN='\033[0;32m'  # Green
readonly YELLOW='\033[0;33m' # Yellow
readonly NC='\033[0m'        # No Color

#
# Description
#
#   Prints an error message on stderr.
#
# Arguments
#
#   $1 - The error message to print.
#
# Usage Example
#
#   print_error "Print an error message."
#
print_error() {
    printf "%b\n" "${RED}[ERROR] ${1}${NC}" >&2
}

#
# Description
#
#   Prints a success message on stdout.
#
# Arguments
#
#   $1 - The success message to print.
#
# Usage Example
#
#   print_success "Print a success message."
#
print_success() {
    printf "%b\n" "${GREEN}[SUCCESS] ${1}${NC}"
}

#
# Description
#
#   Prints a message on stdout.
#
# Arguments
#
#   $1 - The message to print.
#
# Usage Example
#
#   print_info "Print an informational message."
#
print_info() {
    printf "%s\n" "[INFO] ${1}"
}

#
# Description
#
#   Prints a warning message on stderr.
#
# Arguments
#
#   $1 - The warning message to print.
#
# Usage Example
#
#   print_warning "Print a warning message."
#
print_warning() {
    printf "%b\n" "${YELLOW}[WARN] ${1}${NC}" >&2
}

#
# Description
#
#  Prints a panic error message on stderr and exits with status 1.
#
# Arguments
#
#   $1 - The panic error message to print.
#
# Usage Example
#
#   print_panic "Print a panic error message and exit."
#
panic() {
    printf "%b\n" "${RED}[PANIC] ${1}${NC}" >&2
    exit 1
}

#==================================================================================================
# System
#==================================================================================================

#
# Description
#
#  Checks if the current user is the root user.
#
# Return Value
#
#   - Returns 0 (true) if the current user is root.
#   - Returns 1 (false) otherwise.
#
# Usage Example
#
#   is_root_user && echo "Running as root" || echo "Not running as root"
#
is_root_user() {
    [[ $EUID -eq 0 ]]
}

#
# Description
#
#   Gets the OS ID from /etc/os-release.
#
# Return Value
#
#   - On success, a string containing the OS ID (e.g., "ubuntu", "debian").
#   - On failure, returns a non-zero status.
#
# Usage Example
#
#   os_id=$(get_os_id)
#
get_os_id() {
    # Check if /etc/os-release file does not exist.
    if [[ ! -f /etc/os-release ]]; then
        print_error "Cannot determine OS version."
        return 1
    fi

    # Extract OS ID from file and trim whitespace
    local os_id
    os_id=$(sed -n 's/^ID[[:space:]]*=[[:space:]]*"?\([^" ]*\)"?/\1/p' /etc/os-release | head -n1)

    # Check if OS ID was not extracted successfully.
    if [[ -z "$os_id" ]]; then
        print_error "Could not extract OS ID from '/etc/os-release'."
        return 1
    fi

    printf '%s\n' "$os_id"
}

#
# Description
#
#   Gets the OS VERSION_ID from /etc/os-release.
#
# Return Value
#
#   - On success, a string containing the OS VERSION_ID (e.g., "20.04", "10").
#   - On failure, returns a non-zero status.
#
# Usage Example
#
#   os_version_id=$(get_os_version_id)
#
get_os_version_id() {
    # Check if /etc/os-release file does not exist.
    if [[ ! -f /etc/os-release ]]; then
        print_error "Cannot determine OS version."
        return 1
    fi

    # Extract OS VERSION_ID from file and trim whitespace
    local os_version_id
    os_version_id=$(sed -n 's/^VERSION_ID[[:space:]]*=[[:space:]]*"?\([^\"]*\)"?/\1/p' /etc/os-release | head -n1)

    # Check if VERSION_ID was not extracted successfully.
    if [[ -z "$os_version_id" ]]; then
        print_error "Could not extract VERSION_ID from '/etc/os-release'."
        return 1
    fi

    printf '%s\n' "$os_version_id"
}

#==================================================================================================
# Versioning
#==================================================================================================

#
# Description
#
#   Normalizes a version string to have 3 parts (e.g., "4.3" -> "4.3.0").
#
# Arguments
#
#   $1 - The version string to normalize.
#
# Return Value
#
#   - On success, a string containing the normalized version in the format MAJOR.MINOR.PATCH.
#   - On failure, returns a non-zero status.
#
# Usage Example
#
#   normalized_version=$(normalize_version "4.3")
#
normalize_version() {
    local version="$1"

    # Check if version string is empty.
    if [[ -z "$version" ]]; then
        print_error "normalize_version: empty version."
        return 1
    fi

    local parts=0
    IFS='.' read -ra arr <<< "$version"
    parts=${#arr[@]}
    if (( parts < 3 )); then
        while (( parts < 3 )); do
            version="${version}.0"
            ((parts++))
        done
    fi
    printf '%s\n' "$version"
}

#
# Description
#
#   Compares two version strings (e.g., "13.3.0" vs "13.2.5").
#
# Arguments
#
#   $1 - The first version string to compare.
#   $2 - The second version string to compare.
#
# Return Value
#
#   - On success, returns 0 (true) if version1 is greater than or equal to version2,
#     and returns 1 (false) if version1 is less than version2.
#   - On failure, returns a non-zero status.
#
# Usage Example
#
#   if compare_version "13.3.0" "13.2.5"; then
#       echo "Version 13.3.0 is greater than or equal to 13
#   else
#       echo "Version 13.3.0 is less than 13.2.
#   fi
#
compare_version() {
    local version1="$1"
    local version2="$2"

    # Split versions into arrays
    IFS='.' read -ra v1_parts <<< "$version1"
    IFS='.' read -ra v2_parts <<< "$version2"

    # Pad arrays to same length with zeros
    local max_length=$(( ${#v1_parts[@]} > ${#v2_parts[@]} ? ${#v1_parts[@]} : ${#v2_parts[@]} ))

    local i

    # Default to 0 for missing version parts to ensure proper comparison (e.g., "4.3" vs "4.3.0").
    for ((i=0; i<max_length; i++)); do
        local part1=${v1_parts[i]:-0}
        local part2=${v2_parts[i]:-0}

        # Ignore non-digit suffixes (e.g., rc1) by keeping only the leading digits.
        part1=${part1%%[^0-9]*}
        part2=${part2%%[^0-9]*}
        part1=${part1:-0}
        part2=${part2:-0}

        # Use base 10 to avoid octal interpretations (leading zeros).
        if ((10#${part1} > 10#${part2})); then
            return 0
        elif ((10#${part1} < 10#${part2})); then
            return 1
        fi
    done

    # versions are equal.
    return 0
}

#==================================================================================================
# Tools
#==================================================================================================

#
# Get the version of a tool.
#
# Parameters:
#   - $1 Tool name.
#
# Returns:
#   - On success, the version string of the tool.
#   - On failure, returns a non-zero status.
#
# Example:
#
#   get_tool_version "gcc"
#
get_tool_version() {
    local tool="$1"
    local version
    local output

    # Ensure a tool was provided.
    if [[ -z "$tool" ]]; then
        print_error "get_tool_version: no tool specified."
        return 1
    fi

    # If the command isn't available, fail early.
    if ! command -v "$tool" >/dev/null 2>&1; then
        print_error "'${tool}' is not installed."
        return 1
    fi

    case "$tool" in
        gcc | make | wget | zip)
            output=$("$tool" --version 2>&1) || output=$("$tool" -v 2>&1) || output=$("$tool" -V 2>&1) || true
            ;;
        unzip)
            output=$("$tool" 2>&1) || true
            ;;
        *)
            # Try common version invocations. Fall back to --help if none print a version.
            output=$("$tool" --version 2>&1) || output=$("$tool" -v 2>&1) || output=$("$tool" -V 2>&1) || output=$("$tool" version 2>&1) || output=$("$tool" --help 2>&1) || true
            ;;
    esac

    # Extract version: allow 1 to 3 numeric parts (e.g., 1, 1.2, 1.2.3).
    version=$(printf '%s' "$output" | grep -oE '[0-9]+(\.[0-9]+){0,2}' | head -n1)

    # Check if version is empty.
    if [[ -z "$version" ]]; then
        print_error "Unable to determine '${tool}' version."
        return 1
    fi

    printf '%s\n' "$version"
}

#==================================================================================================
# Rust
#==================================================================================================

#
# Description
#
#   Gets the current version from a Cargo.toml file.
#
# Arguments
#
#   $1 - The path to the Cargo.toml file.
#
# Return Value
#
#   - On success, a string containing the current version in the format MAJOR.MINOR.PATCH.
#   - On failure, returns a non-zero status.
#
# Usage Example
#
#   cargo_toml_version=$(get_cargo_toml_version "path/to/Cargo.toml")
#
get_cargo_toml_version() {
    local cargo_toml="$1"

    # Check if the target file does not exist.
    if [[ ! -f "$cargo_toml" ]]; then
        print_error "$cargo_toml does not exist."
        return 1
    fi

    # Check if target file is not a toml file.
    if [[ "${cargo_toml##*.}" != "toml" ]]; then
        print_error "$cargo_toml is not a toml file."
        return 1
    fi

    local cargo_toml_version
    cargo_toml_version=$(awk -F'=' '
        /^\[package\]/{ in_pkg=1; next }
        /^\[/{ in_pkg=0 }
        in_pkg && $1 ~ /version[[:space:]]*/ {
            v=$2
            gsub(/^[[:space:]]+|[[:space:]]+$/,"",v)
            gsub(/^"|"$/,"",v)
            print v
            exit
        }
    ' "$cargo_toml")

    # Check if version was not extracted successfully.
    if [[ -z "$cargo_toml_version" ]]; then
        print_error "Could not extract version from ${cargo_toml}."
        return 1
    fi

    printf '%s\n' "$cargo_toml_version"
}

#
# Description
#
#   Reads a value from a simple, single-level TOML file with key = value pairs.
#
# Arguments
#
#   $1 - The path to the TOML file.
#   $2 - The key to get the value for.
#
# Return Value
#
#   - On success, a string containing the value for the given key.
#   - On failure, returns a non-zero status.
#
# Usage Example
#
#   foobar=$(get_value_from_toml "config.toml" "foobar")
#
get_value_from_toml() {
    local toml_path=$1
    local toml_key=$2
    local val

    # Check if the target file does not exist.
    if [[ ! -f "$toml_path" ]]; then
        print_error "'${toml_path}' does not exist."
        return 1
    fi

    # Escape the key for use in a regex
    local key_escaped
    key_escaped=$(printf '%s' "$toml_key" | sed 's/[][\\/.^$*]/\\&/g')

    # Match quoted (single/double) or unquoted values; return first match only.
    val="$(sed -nE "s/^[[:space:]]*${key_escaped}[[:space:]]*=[[:space:]]*(\"([^\"]*)\"|'([^']*)'|([^[:space:]]+)).*/\2\3\4/p" "$toml_path" | head -n1)"

    if [[ -n "$val" ]] ;then
        printf '%s' "$val"
    else
        print_error "Could not extract '${toml_key}' from '${toml_path}'."
        return 1
    fi
}
