#!/hint/bash

# Copyright © Tavian Barnes <tavianator@tavianator.com>
# SPDX-License-Identifier: 0BSD

## Platform support

# Exit with an unsupported platform error
_idkhowto() {
    _die $EX_SOFTWARE "I don't know how to %s" "$*"
}

# Stub implementations, overridden by platform/*.sh
_stub() {
    local fn="$1"
    shift
    eval "$fn() { _idkhowto $(_quote "$@"); }"
}

_stub ls-cpus     "list CPUs"
_stub pin-to-cpus "pin a command to particular CPUs"
_stub is-cpu-on   "check if a CPU is online"
_stub cpu-off     "turn off a CPU"

_stub ls-nodes     "list NUMA nodes"
_stub pin-to-nodes "pin a command to particular NUMA nodes"

_stub turbo-off "turn off turbo boost"
_stub smt-off   "turn off SMT"
_stub max-freq  "set CPUs to their maximum frequency"
_stub aslr-off  "turn off ASLR"

# Load the platform-specific implementations
_impl="$_TOP/platform/$UNAME.sh"
if [ -e "$_impl" ]; then
    # shellcheck source=./platform/Linux.sh
    source "$_impl"
else
    _warn 'No platform implementation found for %s' "$UNAME"
    _warn '(checked %s)' "$_impl"
fi
