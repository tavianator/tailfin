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

# Log a message
_log() {
    printf '%s: ' "$_CMD"
    # shellcheck disable=SC2059
    printf "$@"
    printf '\n'
}

# Log a warning
_warn() {
    local format="$1"
    shift
    _log "warning: $format" "$@" >&2
}

# Log an error
_err() {
    local format="$1"
    shift
    _log "error: $format" "$@" >&2
}

# Exit with an error and message
_die() {
    local exit="$1"
    shift
    _err "$@" >&2
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
    printf '\n' >&2
    _underline "$(_log "$@")" >&2
}

# Get the first path that refers to an existing file
_first_file() {
    for file; do
        if [ -e "$file" ]; then
            printf '%s' "$file"
            return
        fi
    done

    # If none of the files exist, use the first one so that error messages
    # refer to the preferred name
    printf '%s' "$1"
}

# Redirect standard output/error to log files
_redirect() {
    local out="$1/stdout"
    local err="$1/stderr"
    shift

    # Don't make the logs owned by root
    as-user touch "$out" "$err"

    if ((_quiet)); then
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

# Expand '2,4-6,8' into '2 4 5 6 8'
_explode() {
    awk -F, '{
        space = "";
        for (i = 1; i <= NF; ++i) {
            n = split($i, x, /-/);
            start = x[1];
            end = (n > 1) ? x[2] : start;
            for (j = start; j <= end; ++j) {
                printf "%s%d", space, j;
                space = " ";
            }
        }
    }'
}

# Undo _explode
_implode() {
    #tr '\n' ' ' | awk '{ OFS=","; $1 = $1; print $0 }'}
    tr '\n' ' ' | awk '{
        comma = "";
        for (i = 1; i <= NF; ++i) {
            start = $i;
            while (i < NF && $(i + 1) == $i + 1) {
                ++i;
            }
            end = $i;
            if (start == end) {
                printf "%s%d", comma, start;
            } else {
                printf "%s%d-%d", comma, start, end;
            }
            comma = ",";
        }
    }'
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
_exit_cmds=()
# Commands to run before the regular at-exit commands
_before_exit_cmds=()

# Run commands from an array
_run_handlers() {
    local -n cmds="$1"

    # Run the handlers in the reverse order of installation
    while ((${#cmds[@]} > 0)); do
        local cmd="${cmds[-1]}"
        unset 'cmds[-1]'
        eval "$cmd" || _err 'at-exit command `%s` failed with status %d' "$cmd" $?
    done
}

# Run the registered at-exit handlers
_exit_handler() {
    _run_handlers _before_exit_cmds
    _run_handlers _exit_cmds
}

trap _exit_handler EXIT

# Add a command to an array
_add_handler() {
    # Check if the EXIT trap is set, since at-exit won't work otherwise
    trap -- KILL
    if ! trap -p EXIT | grep -q _exit_handler; then
        _abort "at-exit called without an EXIT handler (are we in a subshell?)"
    fi

    local -n cmds="$1"
    shift
    cmds+=("$(_quote "$@")")
}

# Register a command to run when the script exits
at-exit() {
    _add_handler _exit_cmds "$@"
}

# Register a command to before other at-exit commands
_before_exit() {
    _add_handler _before_exit_cmds "$@"
}

# Get a list of sysctls matching a glob pattern
ls-sysctls() {
    local ctl
    for ctl in $(sysctl -aN); do
        # shellcheck disable=SC2053
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

## Background jobs

# Start a background job and store its ID
_bg() {
    local -n ref="$1"
    shift

    # Use eval so the job gets a nice name
    eval "$(_quote "$@") &"

    # Save the job ID
    ref=$(jobs %% | sed -E 's/.*\[([0-9]+)\].*/%\1/g')
}

# Kill and wait for a background job
_reap() {
    kill "$@"
    wait "$@" 2>/dev/null
}

# Kill and wait for all background jobs
_reapall() {
    while kill %% 2>/dev/null; do
        wait %% || :
    done
}

at-exit _reapall
