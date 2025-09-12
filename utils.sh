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
# Parameters
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
# Parameters
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
# Parameters
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
# Parameters
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
# Parameters
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

    # Source /etc/os-release in a subshell so shell quoting is handled
    # (this avoids exporting variables into the caller shell).
    local os_id
    os_id=$( . /etc/os-release 2>/dev/null; printf '%s' "${ID:-}" )

    # Trim surrounding whitespace just in case.
    os_id=$(printf '%s' "$os_id" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

    # If ID is empty, try the ID_LIKE field (take the first token).
    if [[ -z "$os_id" ]]; then
        local id_like
        id_like=$( . /etc/os-release 2>/dev/null; printf '%s' "${ID_LIKE:-}" )
        id_like=$(printf '%s' "$id_like" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        if [[ -n "$id_like" ]]; then
            # ID_LIKE can be space-separated; use the first entry.
            os_id=$(printf '%s' "$id_like" | awk '{print $1}')
        fi
    fi

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

    # Source /etc/os-release in a subshell so shell quoting is handled.
    local os_version_id
    os_version_id=$( . /etc/os-release 2>/dev/null; printf '%s' "${VERSION_ID:-}" )

    # Trim surrounding whitespace from extracted value.
    os_version_id=$(printf '%s' "$os_version_id" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

    # If VERSION_ID is empty, try falling back to VERSION and extract numeric part.
    if [[ -z "$os_version_id" ]]; then
        local version_raw
        version_raw=$( . /etc/os-release 2>/dev/null; printf '%s' "${VERSION:-}" )
        version_raw=$(printf '%s' "$version_raw" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        if [[ -n "$version_raw" ]]; then
            os_version_id=$(printf '%s' "$version_raw" | grep -oE '[0-9]+(\.[0-9]+)*' | head -n1 || true)
        fi
    fi

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
# Parameters
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
# Parameters
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
# Parameters
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

#
# Description
#
#   Downloads a zip archive to /tmp and optionally verifies its SHA256 checksum.
#
# Parameters
#  - $1 URL of the dependency to download
#  - $2 (Optional) Expected SHA256 checksum (with or without "sha256:" prefix)
#
# Returns Value
#
#   - On success, the path to the downloaded file.
#   - On failure, returns a non-zero status.
#
# Usage Example
#
#   file_path=$(download "https://example.com/foo.zip" "sha256:...")
#
download() {
    local dependency_url="$1"
    local expected_checksum="${2:-}"

    if [[ -z "$dependency_url" ]]; then
        print_error "download requires URL parameter"
        return 1
    fi

    # Generate temporary file name based on URL
    local filename
    filename=$(basename "$dependency_url")
    local temp_file="/tmp/${filename}"


    # Download dependency, if it does not already exist.
    if [[ ! -f "$temp_file" ]]; then
        wget -q "$dependency_url" -O "$temp_file" || {
            print_error "Failed to download from $dependency_url"
            return 1
        }
    fi

    # Verify the checksum of the downloaded file, if provided.
    if [[ -n "$expected_checksum" ]]; then
        # Remove "sha256:" prefix if present
        local clean_checksum="${expected_checksum#sha256:}"
        local actual_checksum
        actual_checksum=$(sha256sum "$temp_file" | awk '{print $1}')

        if [[ "$actual_checksum" != "$clean_checksum" ]]; then
            print_error "Checksum verification failed for $temp_file"
            return 1
        fi
    fi

    # Return path to downloaded file
    printf '%s\n' "$temp_file"
}

#
# Description
#
#   Extracts a zip archive to a given location and fixes ownership of the extracted files.
#
# Parameters
#
#  - $1 Path to the zip file
#  - $2 Extract location directory
#
# Usage Example
#
#   extract_zip "/tmp/foo.zip" "/opt/foo" && echo "Extraction succeeded" || echo "Extraction failed"
#
extract_zip() {
    local zip_file="$1"
    local extract_location="$2"

    # Check if any parameter is missing.
    if [[ -z "$zip_file" || -z "$extract_location" ]]; then
        print_error "extract_zip requires zip file and extract location parameters"
        return 1
    fi

    print_info "Extracting ${zip_file} to $extract_location"
    # Attempt to create the extract directory if it does not exist.
    mkdir -p "$extract_location" || {
        print_error "Failed to create extract directory '${extract_location}'"
        return 1
    }

    unzip -q "$zip_file" -d "$extract_location" || {
        print_error "Failed to extract '${zip_file}' to '${extract_location}'"
        return 1
    }

    # Fix ownership of the extracted files.
    print_info "Fixing ownership of the extracted files..."
    if ! chown -R "$(id -u):$(id -g)" "$extract_location"; then
        print_warning "Could not change ownership of extracted files in '$extract_location'. You may need to adjust permissions manually."
    fi

    return 0
}

#
# Description
#
#   Extracts a .tar.bz2 (or .tbz/.tbz2) archive to a given location and fixes ownership of the extracted files.
#
# Parameters
#
#  - $1 Path to the tar.bz2 file
#  - $2 Extract location directory
#
# Usage Example
#
#   extract_tar_bz2 "/tmp/foo.tar.bz2" "/opt/foo" && echo "Extraction succeeded" || echo "Extraction failed"
#
extract_tar_bz2() {
    local tar_file="$1"
    local extract_location="$2"

    # Check if any parameter is missing.
    if [[ -z "$tar_file" || -z "$extract_location" ]]; then
        print_error "extract_tar_bz2 requires tar file and extract location parameters"
        return 1
    fi

    # Check that the archive exists.
    if [[ ! -f "$tar_file" ]]; then
        print_error "Tar archive '$tar_file' does not exist."
        return 1
    fi

    print_info "Extracting ${tar_file} to $extract_location"
    # Attempt to create the extract directory if it does not exist.
    mkdir -p "$extract_location" || {
        print_error "Failed to create extract directory '${extract_location}'"
        return 1
    }

    # Extract using tar. Support bzip2-compressed tarballs (.tar.bz2, .tbz, .tbz2).
    if ! tar -xjf "$tar_file" -C "$extract_location" >/dev/null 2>&1; then
        print_error "Failed to extract '${tar_file}' to '${extract_location}'"
        return 1
    fi

    # Fix ownership of the extracted files.
    print_info "Fixing ownership of the extracted files..."
    if ! chown -R "$(id -u):$(id -g)" "$extract_location"; then
        print_warning "Could not change ownership of extracted files in '$extract_location'. You may need to adjust permissions manually."
    fi

    return 0
}

#==================================================================================================
# Rust
#==================================================================================================

#
# Description
#
#   Gets the current version from a Cargo.toml file.
#
# Parameters
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
# Parameters
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

#==================================================================================================
# Project Commands
#==================================================================================================

# Project directory.
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"

# Name for project build command.
readonly BUILD_CMD_NAME="build"
# Default name for peojct configure command.
readonly CONFIGURE_CMD_NAME="configure"
# Name for project help command.
readonly HELP_CMD_NAME="help"
# Name for project install command.
readonly INSTALL_CMD_NAME="install"
# Name for project release command.
readonly RELEASE_CMD_NAME="release"
# Name for project setup command.
readonly SETUP_CMD_NAME="setup"
# Name for show config command.
readonly SHOW_CONFIG_CMD_NAME="show-config"

# Name for install location option.
readonly INSTALL_LOCATION_OPT_NAME="--install-location"
# Name for parallel build option.
readonly PARALLEL_BUILD_OPT_NAME="--parallel-build"
# Name for release name option.
readonly RELEASE_NAME_OPT_NAME="--release-name"
# Name for stage option.
readonly STAGE_OPT_NAME="--stage"
# Name for sysroot location option.
readonly SYSROOT_LOCATION_OPT_NAME="--sysroot-location"

# Configuration file path
readonly Z_CONFIG_FILE="${PROJECT_DIR}/.z.config"

# ID of supported OS
readonly SUPPORTED_OS_ID="ubuntu"
# Version of supported OS
readonly SUPPORTED_OS_VERSION="24.04"

# Default target value.
readonly DEFAULT_TARGET="i686-nanvix"
# Default build stage.
readonly DEFAULT_STAGE="0"
# Default install location.
readonly DEFAULT_INSTALL_LOCATION="${HOME}/nanvix"
# Default sysroot location.
readonly DEFAULT_SYSROOT_LOCATION=""

# Target.
Z_TARGET="${DEFAULT_TARGET}"
# Build stage.
Z_STAGE="${DEFAULT_STAGE}"
# Install location.
Z_INSTALL_LOCATION="$DEFAULT_INSTALL_LOCATION"
# Number of parallel build jobs.
Z_PARALLEL_BUILD=""
# Release name.
Z_RELEASE_NAME=
# Sysroot location.
Z_SYSROOT_LOCATION="$DEFAULT_SYSROOT_LOCATION"

#
# Description
#
#   Returns the default release name for the project.
#
# Return Value
#
#   A string containing the default release name.
#
# Usage Example
#
#   default_release_name=$(get_default_release_name)
#
_get_default_release_name() {
    local z_project_name

    # Check if Z_PROJECT_NAME is set.
    if [[ -z "${Z_PROJECT_NAME:-}" ]]; then
        # If not set, fall back to using the project directory name.
        z_project_name=$(basename "$PROJECT_DIR")
    else
        z_project_name="${Z_PROJECT_NAME}"
    fi

    printf '%s\n' "nanvix-${z_project_name,,}"
}

#
# Description
#
#   Creates the build directory, if the project uses one.
#
# Parameters
#
#   - $1: Project build directory.
#
# Return Value
#
#   - On success, returns zero.
#   - On failure, returns non-zero.
#
# Usage Example
#
#   _create_build_directory "/path/to/build"
#
_create_build_directory() {
    local project_build_dir=$1

    # Create build directory if and only if the project uses one.
    if [[ -n "${project_build_dir}" ]]; then
        mkdir -p "${project_build_dir}" || {
            print_error "Failed to create build directory"
            return 1
        }
    fi

    return 0
}

#
# Description
#
#   Enters the build directory, if any.
#
# Parameters
#
#   - $1: Project build directory.
#
# Return Value
#
#   - On success, returns zero.
#   - On failure, returns non-zero.
#
# Usage Example
#
#   _enter_build_directory "/path/to/build"
#
_enter_build_directory() {
    local project_build_dir=$1

    # Enter build directory if and only if the project uses one.
    if [[ -n "${project_build_dir}" ]]; then
        pushd "${project_build_dir}" || {
            print_error "failed to enter directory '${project_build_dir}'"
            return 1
        }
    fi

    return 0
}

#
# Description
#
#   Leaves the build directory, if any was entered.
#
# Parameters
#
#   - $1: Project build directory.
#
# Return Value
#
#   - On success, returns zero.
#   - On failure, returns non-zero.
#
# Usage Example
#
#   _leave_build_directory "/path/to/build"
#
_leave_build_directory() {
    local project_build_dir=$1

    # Leave build directory if and only if the project uses one.
    if [[ -n "${project_build_dir}" ]]; then
        popd || {
            print_error "failed to leave directory '${project_build_dir}'"
            return 1
        }
    fi

    return 0
}

#
# Description
#
#   Installs required system packages to build the project.
#
# Global Variables
#
#   - Z_PROJECT_NAME: Name of the project (for logging purposes).
#   - Z_PROJECT_REQUIRED_PACKAGES: Array of required system packages to install.
#
# Return Value
#
#  - On success, returns zero.
#  - On failure, returns non-zero.
#
# Usage Example
#
#  _setup_project && echo "Success" || echo "Failure"
#
_setup_project() {
    print_info "Setting up required system packages for ${Z_PROJECT_NAME}..."

    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        print_info "Running as root - proceeding with package installation"
    else
        print_info "Checking if sudo is available..."
        if ! command -v sudo >/dev/null 2>&1; then
            print_error "sudo is not available"
            return 1
        fi
        print_info "Will use sudo for package installation"
    fi

    # Update package list
    print_info "Updating package list..."
    if [[ $EUID -eq 0 ]]; then
        apt-get update
    else
        sudo apt-get update
    fi

    # Install missing packages from Z_PROJECT_REQUIRED_PACKAGES
    print_info "Installing packages: ${Z_PROJECT_REQUIRED_PACKAGES[*]}"
    if [[ $EUID -eq 0 ]]; then
        apt-get install -y "${Z_PROJECT_REQUIRED_PACKAGES[@]}"
    else
        sudo apt-get install -y "${Z_PROJECT_REQUIRED_PACKAGES[@]}"
    fi

    return 0
}

#
# Description
#
#   Installs the project.
#
# Global Variables
#
#   - Z_PROJECT_NAME: Name of the project (for logging purposes).
#   - INSTALL_LOCATION: Directory where the project will be installed.
#
# Return Value
#
#  - On success, returns zero.
#  - On failure, returns non-zero.
#
# Usage Example
#
#  install && echo "Success" || echo "Failure"
#
_install_project() {
    echo "Installing ${Z_PROJECT_NAME} for Nanvix..."
    echo "Install location: ${Z_INSTALL_LOCATION}"

    _enter_build_directory "$Z_PROJECT_BUILD_DIR" || {
        print_error "Failed to enter build directory"
        return 1
    }

    local old_path="$PATH"

    # If sysroot locaiton is set add it to PATH. Otherwise, add install location.
    local sysroot_location="${Z_SYSROOT_LOCATION:-${Z_INSTALL_LOCATION}}"
    export PATH="${sysroot_location}/bin:${PATH}"

    install_steps || {
        export PATH="${old_path}"
        return 1
    }

    export PATH="${old_path}"

    _leave_build_directory "$Z_PROJECT_BUILD_DIR" || {
        print_error "Failed to leave build directory"
        return 1
    }

    return 0
}

#
# Description
#
#   Builds the project.
#
# Global Variables
#
#   - Z_PROJECT_NAME: Name of the project (for logging purposes).
#   - TARGET: Build target (for logging purposes).
#   - Z_PROJECT_BUILD_DIR: Directory where the project is built.
#
# Return Value
#
#  - On success, returns zero.
#  - On failure, returns non-zero.
#
# Usage Example
#
#  build && echo "Success" || echo "Failure"
#
_build_project() {
    echo "Building ${Z_PROJECT_NAME} for ${Z_TARGET}..."

    local parallel_build_option
    if [[ -n "$Z_PARALLEL_BUILD" ]]; then
        if ! [[ "$Z_PARALLEL_BUILD" =~ ^[0-9]+$ ]] || [[ "$Z_PARALLEL_BUILD" -le 0 ]]; then
            print_error "${PARALLEL_BUILD_OPT_NAME} must be a positive integer greater than zero"
            return 1
        fi
        print_info "Using $Z_PARALLEL_BUILD parallel jobs"
        parallel_build_option="${Z_PARALLEL_BUILD}"
    else
        print_info "Using all available CPU cores ($(nproc))"
        parallel_build_option="$(nproc)"
    fi

    _enter_build_directory "$Z_PROJECT_BUILD_DIR" || {
        print_error "Failed to enter build directory"
        return 1
    }

    local old_path="$PATH"

    # If sysroot locaiton is set add it to PATH. Otherwise, add install location.
    local sysroot_location="${Z_SYSROOT_LOCATION:-${Z_INSTALL_LOCATION}}"
    export PATH="${sysroot_location}/bin:${PATH}"

    build_steps "${parallel_build_option}" || {
        export PATH="${old_path}"
        return 1
    }

    export PATH="${old_path}"

    _leave_build_directory "$Z_PROJECT_BUILD_DIR" || {
        print_error "Failed to leave build directory"
        return 1
    }

    return 0
}

#
# Description
#
#   Configures the project.
#
# Global Variables
#
#   - Z_PROJECT_NAME: Name of the project (for logging purposes).
#   - Z_TARGET: Build target (for logging purposes).
#   - Z_SYSROOT_LOCATION: Location of the sysroot (for logging purposes).
#   - Z_PROJECT_BUILD_DIR: Directory where the project will be built.
#
# Return Value
#
#   - On success, returns zero.
#   - On failure, returns non-zero.
#
# Usage Example
#
#   configure && echo "Success" || echo "Failure"
#
_configure_project() {
    print_info "Configuring ${Z_PROJECT_NAME} for ${Z_TARGET}..."
    print_info "Sysroot location: ${Z_SYSROOT_LOCATION}"

    # Save configuration parameters
    _save_project_config || {
        print_error "Failed to save build configuration"
        return 1
    }

    _check_project_tools || {
        print_error "Required tools are missing or do not meet the minimum version"
        return 1
    }

    download_steps || {
        print_error "Failed to download dependencies"
        return 1
    }

    _create_build_directory "$Z_PROJECT_BUILD_DIR" || {
        print_error "Failed to create build directory"
        return 1
    }

    _enter_build_directory "$Z_PROJECT_BUILD_DIR" || {
        print_error "Failed to enter build directory"
        return 1
    }

    local old_path="$PATH"

    # If sysroot locaiton is set add it to PATH. Otherwise, add install location.
    local sysroot_location="${Z_SYSROOT_LOCATION:-${Z_INSTALL_LOCATION}}"
    export PATH="${sysroot_location}/bin:${PATH}"

    configure_steps || {
        print_error "Configuration failed"
        export PATH="${old_path}"
        return 1
    }

    export PATH="${old_path}"

    _leave_build_directory "$Z_PROJECT_BUILD_DIR" || {
        print_error "Failed to leave build directory"
        return 1
    }

    return 0
}

#
# Description
#
#   Creates a release of the project.
#
# Global Variables
#
#   - RELEASE_NAME: Name of the release (used for naming the tarball).
#   - INSTALL_LOCATION: Directory where the project is installed (to be archived).
#
# Return Value
#
#  - On success, returns zero.
#  - On failure, returns non-zero.
#
# Usage Example
#
#  _release_project && echo "Success" || echo "Failure"
#
_release_project() {
    _configure_project|| {
        print_error "Configuration failed"
        return 1
    }
    _build_project || {
        print_error "Build failed"
        return 1
    }
    _install_project || {
        print_error "Installation failed"
        return 1
    }

    print_info "Creating release..."

    local release_name="${Z_RELEASE_NAME:-$(_get_default_release_name)}"

    local tar_file_name="${release_name}.tar.bz2"

    pushd "$Z_INSTALL_LOCATION" || {
        print_error "Failed to change directory to ${Z_INSTALL_LOCATION}"
        return 1
    }

    # Create a bzip2-compressed tarball of the install location
    tar -cjf "${PROJECT_DIR}/${tar_file_name}" . || {
        print_error "Failed to create tar.bz2 file"
        return 1
    }

    popd || {
        print_error "Failed to return to the previous directory after creating the release"
        return 1
    }

    print_info "Release created: ${PROJECT_DIR}/${tar_file_name}"

    return 0
}

#
# Description
#
#   Displays a help message.
#
# Usage Example
#
#   _project_help
#
_project_help() {
    local default_release_name
    default_release_name=$(_get_default_release_name)

    cat << EOF
Utility for building and installing ${Z_PROJECT_NAME} for Nanvix.

Usage: ./z COMMAND   [OPTIONS]
       ./z ${BUILD_CMD_NAME}
       ./z ${CONFIGURE_CMD_NAME} [${PARALLEL_BUILD_OPT_NAME}=N] [${INSTALL_LOCATION_OPT_NAME}=PATH] [${SYSROOT_LOCATION_OPT_NAME}=PATH] [${STAGE_OPT_NAME}=N]
       ./z ${HELP_CMD_NAME}
       ./z ${INSTALL_CMD_NAME}
       ./z ${RELEASE_CMD_NAME}
       ./z ${SETUP_CMD_NAME}
       ./z ${SHOW_CONFIG_CMD_NAME}

Commands:
  ${BUILD_CMD_NAME}        Build ${Z_PROJECT_NAME} for Nanvix
  ${CONFIGURE_CMD_NAME}    Configure ${Z_PROJECT_NAME} for Nanvix
  ${HELP_CMD_NAME}         Print help
  ${INSTALL_CMD_NAME}      Install ${Z_PROJECT_NAME} for Nanvix
  ${RELEASE_CMD_NAME}      Create a release of ${Z_PROJECT_NAME} for Nanvix
  ${SETUP_CMD_NAME}        Install required packages to build ${Z_PROJECT_NAME} for Nanvix
  ${SHOW_CONFIG_CMD_NAME}  Show current configuration

Options:
  ${INSTALL_LOCATION_OPT_NAME}=PATH  Set install location to 'PATH'          (defaults to '${DEFAULT_INSTALL_LOCATION}')
  ${PARALLEL_BUILD_OPT_NAME}=N       Use 'N' parallel threads when building  (defaults to using all available CPU cores)
  ${RELEASE_NAME_OPT_NAME}=NAME      Set the release name to 'NAME'          (defaults to '${default_release_name}')
  ${STAGE_OPT_NAME}=N                Set build stage to 'N'                  (defaults to '${DEFAULT_STAGE}')
  ${SYSROOT_LOCATION_OPT_NAME}=PATH  Set sysroot location to 'PATH'          (defaults to '${DEFAULT_SYSROOT_LOCATION}')
EOF
}

#
# Description
#
#   Parses command line arguments.
#
# Parameters
#
#   - $@: Command line arguments passed to the script or to a subcommand.
#
# Return Value
#
#   - On success, this function returns zero.
#   - On failure, this function returns non-zero.
#
# Usage Example
#
#   parse_args "$@"
#
_parse_project_args() {
    while [[ $# -gt 0 ]] ; do
        case "$1" in
            "${INSTALL_LOCATION_OPT_NAME}="*)
                Z_INSTALL_LOCATION="${1#*=}"
                shift
                ;;
            "${PARALLEL_BUILD_OPT_NAME}="*)
                Z_PARALLEL_BUILD="${1#*=}"
                shift
                ;;
            "${RELEASE_NAME_OPT_NAME}="*)
                Z_RELEASE_NAME="${1#*=}"
                shift
                ;;
            "${STAGE_OPT_NAME}="*)
                # shellcheck disable=SC2034
                Z_STAGE="${1#*=}"
                shift
                ;;
            "${SYSROOT_LOCATION_OPT_NAME}="*)
                Z_SYSROOT_LOCATION="${1#*=}"
                shift
                ;;
            *)
                print_error "Unknown option '$1'"
                return 1
                ;;
        esac
    done
}


#
# Description
#
#   Saves the current configuration parameters to a temporary file.
#
# Return Value
#
#   - On success, this function returns zero.
#   - On failure, this function returns non-zero.
#
# Usage Example
#
#   save_config && echo "Success" || echo "Failure"
#
_save_project_config() {
    local release_name="${Z_RELEASE_NAME:-$(_get_default_release_name)}"
    cat > "$Z_CONFIG_FILE" << EOF
Z_TARGET="$Z_TARGET"
Z_INSTALL_LOCATION="$Z_INSTALL_LOCATION"
Z_SYSROOT_LOCATION="$Z_SYSROOT_LOCATION"
Z_PARALLEL_BUILD="$Z_PARALLEL_BUILD"
Z_RELEASE_NAME="${release_name}"
EOF

    print_info "Configuration parameters saved to $Z_CONFIG_FILE"

    return 0
}

#
# Description
#
#   Loads configuration parameters from the temporary file.
#
# Return Value
#
#   - Returns zero if configuration parameters were loaded successfully.
#   - Returns non zero if the configuration file does not exist or could not be sourced.
#
# Usage Example
#
#   load_config && echo "Success" || echo "Failure"
#
_load_project_config() {
    if [[ -f "$Z_CONFIG_FILE" ]]; then
        # shellcheck disable=SC1090
        source "$Z_CONFIG_FILE" || {
            print_error "Failed to source configuration file: $Z_CONFIG_FILE"
            return 1
        }
    else
        print_error "Configuration file not found: $Z_CONFIG_FILE"
        return 1
    fi

    return 0
}

#
# Description
#
#   Shows current project configuration.
#
# Return Value
#
#   - Returns zero if configuration parameters were loaded and displayed successfully.
#   - Returns non zero if the configuration file does not exist or could not be sourced.
#
# Usage Example
#
#   _show_project_config
#
_show_project_config() {
    if _load_project_config; then
        print_info "Current configuration:"
        print_info "  Target: $Z_TARGET"
        print_info "  Install location: $Z_INSTALL_LOCATION"
        print_info "  Sysroot location: $Z_SYSROOT_LOCATION"
        [[ -n "$Z_PARALLEL_BUILD" ]] && print_info "  Parallel build: $Z_PARALLEL_BUILD"
        print_info "  Release name: ${Z_RELEASE_NAME:-$(_get_default_release_name)}"
        return 0
    else
        return 1
    fi
}

#
# Description
#
#   Checks if required tools are available.
#
# Return Value
#
#   - Returns zero if all required tools are available and meet the minimum version.
#   - Returns non zero if any tool is missing or does not meet the minimum version.
#
# Usage Example
#
#   declare -A required_tools=( ["gcc"]="13.3.0" ["make"]="4.3.0" )
#   _check_project_tools required_tools
#
_check_project_tools() {
    print_info "Checking for required development tools..."

    for tool in "${!Z_PROJECT_REQUIRED_TOOLS[@]}"; do
        print_info "Checking if $tool exists..."

        local min_version="${Z_PROJECT_REQUIRED_TOOLS[$tool]}"

        if ! command -v "$tool" >/dev/null 2>&1; then
            print_error "$tool is not installed or not in PATH"
            return 1
        fi

        # Get version string.
        local version
        version=$(get_tool_version "$tool")
        if [[ -z "$version" ]]; then
            print_error "Unable to determine $tool version"
            return 1
        fi

        # Normalize versions to three parts for consistent comparison.
        version=$(normalize_version "$version")
        min_version=$(normalize_version "$min_version")

        # Check if tool version is older than the minimum required version.
        if ! compare_version "$version" "$min_version"; then
            print_error "$tool version $version is too old (required >= $min_version)"
            return 1
        fi

        print_info "$tool $version found"
    done

    print_info "All required tools are available."

    return 0
}

#
# Description
#
#   Validates if the current OS is supported.
#
# Return Value
#
#   - On success, returns zero.
#   - On failure, returns non-zero.
#
# Usage Example
#
#   _check_os_compatibility && echo "Success" || echo "Failure"
#
_check_project_os_support() {
    local osid
    osid=$(get_os_id) || {
        print_error "Failed to get OS ID"
        return 1
    }
    if [[ "${osid}" != "${SUPPORTED_OS_ID}" ]]; then
        print_error "Unsupported OS '${osid}'"
        print_info "This script supports only Ubuntu."
        return 1
    fi

    local osver
    osver=$(get_os_version_id) || {
        print_error "Failed to get OS version"
        return 1
    }
    if [[ "${osver}"  != "${SUPPORTED_OS_VERSION}" ]]; then
        print_error "Unsupported Ubuntu version '${osver}'"
        print_info "This script supports only Ubuntu 24.04."
        return 1
    fi

    return 0
}


# Main function
zmain() {
    # Validate OS compatibility first
    _check_project_os_support || {
        print_error "Unsupported OS. This script supports only Ubuntu ${SUPPORTED_OS_VERSION}."
        return 1
    }

    # Check if no command was specified.
    if [[ $# -eq 0 ]]; then
        _project_help
        return 1
    fi

    local command="$1"
    shift

    # Handle commands
    case "$command" in
        "$HELP_CMD_NAME")
            _project_help
            return 0
            ;;
        "$BUILD_CMD_NAME" | \
        "$CONFIGURE_CMD_NAME" | \
        "$INSTALL_CMD_NAME" | \
        "$RELEASE_CMD_NAME" | \
        "$SETUP_CMD_NAME" | \
        "$SHOW_CONFIG_CMD_NAME")
            # Valid commands - will be handled below
            ;;
        *)
            _project_help
            print_error "Unknown command: $command"
            return 1
            ;;
    esac

    # Handle setup command.
    if [[ "$command" == "$SETUP_CMD_NAME" ]]; then
        _setup_project || {
            print_error "Setup failed"
            return 1
        }
        print_success "Setup completed successfully."
        return 0
    fi

    # For all other commands, check if required tools are available.
    _check_project_tools || {
        print_error "Required tools are missing or do not meet the minimum version"
        return 1
    }

    # Handle configure command.
    if [[ "$command" == "$CONFIGURE_CMD_NAME" ]]; then
        _parse_project_args "$@" || {
            print_error "Failed to parse arguments"
            return 1
        }

        _configure_project || {
            print_error "Configuration failed"
            return 1
        }
        print_success "Configuration completed successfully."
        return 0
    fi

    # For other commands, load saved configuration.
    _load_project_config || {
        print_error "Failed to load build configuration."
        return 1
    }

    # Handle all other commands.
    case "$command" in
        "${BUILD_CMD_NAME}")
            _build_project || {
                print_error "Build failed"
                return 1
            }
            print_success "Build completed successfully."
            ;;
        "${INSTALL_CMD_NAME}")
            _install_project || {
                print_error "Installation failed"
                return 1
            }
            print_success "Installation completed successfully."
            ;;
        "${RELEASE_CMD_NAME}")
            _release_project || {
                print_error "Release creation failed"
                return 1
            }
            print_success "Release created successfully."
            ;;
        "${SHOW_CONFIG_CMD_NAME}")
            _show_project_config || {
                print_error "Could not show configuration."
                return 1
            }
            ;;
        *)
            # If still unknown, show help.
            _project_help
            print_error "Unknown command: $command"
            return 1
            ;;
    esac

    return 0
}
