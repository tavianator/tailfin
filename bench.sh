#!/hint/bash

# Copyright © Tavian Barnes <tavianator@tavianator.com>
# SPDX-License-Identifier: 0BSD

## If we invoked ourselves with -x, directly run the script's bench() function

if ((_bench)); then
    # shellcheck source=./demo.sh
    source "$_script" "$@"
    (bench "$@")
    exit $?
fi

## Set up the working directory

_dir="$_dir/$(date '+%Y/%m/%d/%T')"
if [ -e "$_dir" ]; then
    _die $EX_CANTCREAT '"%s" already exists' "$_dir"
fi

_init="$_dir/init"
_setup="$_dir/setup"
_teardown="$_dir/teardown"
as-user mkdir -p "$_init" "$_setup" "$_teardown"

## Make the EXIT trap output to the teardown log

_before_exit _phase 'Tearing down ...'
_before_exit _redirect "$(realpath -- "$_teardown")" exec

## Describe this benchmarking run

_info() {
    _underline "$(printf '%s\n' "${_args[*]}")"

    printf 'uname: '
    uname -a
    printf 'uptime: '
    uptime
    printf 'cwd: %s\n' "$PWD"
    printf 'runs: %s\n' "$_runs"
    printf 'user: %s\n' "$_user"
    printf 'quiet: %s\n' "$_quiet"
    printf 'script: %s\n' "$_script"
}

_redirect "$_init" _info

# Save the complete environment
as-user touch "$_init/env"
env >"$_init/env"

## Load and run the script

_redirect "$_init" _phase 'Loading "%s" ...' "$_script"
_redirect "$_init" source "$_script" "$@"

if ! is-function bench; then
    _die $EX_DATAERR '%s does not define the function bench()' "$_script"
fi

if is-function setup; then
    export SETUP_DIR="$_setup"
    _redirect "$SETUP_DIR" _phase 'Running setup() ...'
    _redirect "$SETUP_DIR" setup "$@"
fi

for _run in $(seq -w "$_runs"); do
    export BENCH_DIR="$_dir/runs/$_run"
    as-user mkdir -p "$BENCH_DIR"

    _redirect "$BENCH_DIR" _phase 'Running bench(), iteration %s ...' "$_run"
    _redirect "$BENCH_DIR" as-user "$0" -x -- "$_script" "$@"
done
