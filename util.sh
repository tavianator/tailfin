#!/hint/bash

# Copyright © Tavian Barnes <tavianator@tavianator.com>
# SPDX-License-Identifier: 0BSD

# This file contains shared constants and utility functions.  We follow these
# naming conventions:
#
#     # Constant that shouldn't change between runs
#     SOME_CONST=...
#
#     # Variable that might change between runs
#     some_var=...
#
#     # Utility function
#     some-fn() { ... }
#
#     # Implementation details, not intended for use by benchmarks themselves:
#     _SOME_CONST=...
#     _some_var=...
#     _some_fn() { ... }


## Constants

# sysexits(3)
EX_USAGE=64
EX_DATAERR=65
EX_NOINPUT=66
EX_NOUSER=67
EX_NOHOST=68
EX_UNAVAILABLE=69
EX_SOFTWARE=70
EX_OSERR=71
EX_OSFILE=72
EX_CANTCREAT=73
EX_IOERR=74
EX_TEMPFAIL=75
EX_PROTOCOL=76
EX_NOPERM=77
EX_CONFIG=78

# The current platform (kernel)
UNAME=$(uname)

# The basename of the command itself
_CMD=$(basename -- "$0")

## Utility functions

# Join parameters with a custom separator
_join() {
    local IFS="$1"
    shift
    printf '%s' "$*"
}

# Log a message
_log() {
    printf '%s: ' "$_CMD"
    printf "$@"
    printf '\n'
}

# Log a warning
_warn() {
    local format="$1"
    shift
    _log "warning: $format" "$@" >&2
}

# Exit with an error and message
_die() {
    local exit="$1"
    shift
    _log "$@" >&2
    exit "$exit"
}

# Abort execution due to a bug
_abort() {
    _die $EX_SOFTWARE "$@"
}

# Underline some text
_underline() {
    local str="$*"
    printf '%s\n' "$str"
    printf '%*s\n\n' ${#str} "" | tr ' ' '='
}

# Delineate an execution phase
_phase() {
    printf '\n'
    _underline "$(_log "$@")"
}

# Redirect standard output/error to log files
_redirect() {
    local out="$1/stdout"
    local err="$1/stderr"
    shift

    # Don't make the logs owned by root
    as-user touch "$out"
    as-user touch "$err"

    if [ "$_quiet" ]; then
        "$@" >>"$out" 2>>"$err"
    else
        "$@" > >(tee -ai "$out") 2> >(tee -ai "$err" >&2)
    fi
}

# Quote a command safely for eval
_quote() {
    printf '%q' "$1"
    shift
    if (($# > 0)); then
        printf ' %q' "$@"
    fi
}

# Check if a command exists
is-command() {
    command -v "$1" >/dev/null
}

# Check if a function is defined
is-function() {
    [ "$(type -t "$1")" = "function" ]
}

# Run a command as the target user (-u or $SUDO_USER)
as-user() {
    if [ "$_user" ]; then
        sudo -Eu "$_user" -- "$@"
    else
        "$@"
    fi
}

## Automatic cleanup

# It's often useful to make system-wide configuration changes to stabilize the
# results of a benchmark.  We try hard to undo those changes once the benchmark
# finishes, even if it crashes.  To achieve this, many changes automatically
# register a command to undo themselves, and these commands are run by a handler
# for the EXIT trap.  This is still just best-effort, but it's much better than
# only cleaning up after a successful run.
#
# The low-level primitive we expose is the at-exit function:
#
#     # Get the current overcommit setting
#     saved=$(sysctl -n vm.overcommit_memory)
#     # Disable overcommit:
#     sysctl vm.overcommit_memory=2
#     # Re-enable it at exit:
#     at-exit sysctl vm.overcommit_memory=$saved
#
# We also provide higher-level helpers that are often more convenient:
#
#     # Disable overcommit
#     set-sysctl vm.overcommit_memory 2

# The array of commands for the EXIT handler to run:
_atexit_cmds=()

# A directory to store the EXIT handler's logs
_atexit_logs=

# Run the registered at-exit handlers
_atexit_handler() {
    if [ "$_atexit_logs" ]; then
        _redirect "$_atexit_logs" exec
    fi

    # Run the handlers in the reverse order of installation
    while ((${#_atexit_cmds[@]} > 0)); do
        local cmd="${_atexit_cmds[-1]}"
        unset '_atexit_cmds[-1]'
        eval "$cmd" || _warn 'at-exit command `%s` failed with status %d' "$cmd" $?
    done
}

trap _atexit_handler EXIT

# Register a command to run when the script exits
at-exit() {
    # Check if the EXIT trap is set, since at-exit won't work otherwise
    trap -- KILL
    if trap -p EXIT | grep _atexit_handler &>/dev/null; then
        _atexit_cmds+=("$(_quote "$@")")
    else
        _abort "at-exit called without an EXIT handler (are we in a subshell?)"
    fi
}

# Get a list of sysctls matching a glob pattern
ls-sysctls() {
    local ctl
    for ctl in $(sysctl -aN); do
        if [[ "$ctl" == $1 ]]; then
            printf '%s\n' "$ctl"
        fi
    done
}

# Set a sysctl for the duration of a benchmark
set-sysctl() {
    local prev
    prev=$(sysctl -n "$1")

    sysctl "$1=$2" >&2
    at-exit sysctl "$1=$prev" >&2
}

# Helper to write a string to a sysfs file
_write_sysfs() {
    # Log the old and new values
    printf '%s: %s -> %s\n' "$1" "$2" "$3" >&2
    # Write the new value
    printf '%s' "$3" >"$1"
}

# Undo a sysfs change, warning on unexpected changes
_undo_sysfs() {
    # Warn if the current value is not what we expected
    local cur
    cur=$(cat "$1")
    if [ "$cur" != "$3" ]; then
        _warn '%s changed unexpectedly' "$1"
        _warn 'contents: %s' "$cur"
        _warn 'expected: %s' "$3"
    fi

    _write_sysfs "$1" "$cur" "$2"
}

# Set a sysfs value for the duration of a benchmark
set-sysfs() {
    local prev
    prev=$(cat "$1")
    if [ "$prev" = "$2" ]; then
        return
    fi

    _write_sysfs "$1" "$prev" "$2"
    at-exit _undo_sysfs "$1" "$prev" "$2"
}
