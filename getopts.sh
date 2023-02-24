#!/hint/bash

# Copyright © Tavian Barnes <tavianator@tavianator.com>
# SPDX-License-Identifier: 0BSD

## Command line parsing

_help() {
    cat <<EOF
Usage: $_CMD [<options>] <subcommand> [<args>]

Run a benchmark:

  $_CMD run <script> [<args>]

Manage previous runs:

  $_CMD ls
      List previous runs
  $_CMD latest
      Print the most recent run
  $_CMD view [<run>]
      View the logs of a previous run (default: latest)
  $_CMD save <name> [<run>]
      Save a previous run with a special name
  $_CMD clean
      Delete any prior runs that were not saved

View help:

  $_CMD help
  $_CMD -h

Options:

  -d <dir>
      Set the directory for results and logs (default: ./results).  The current
      date and time will be appended to this path to distinguish runs.

  -n
      Don't save benchmark logs for this run

  -r <runs>
      Run the benchmark this many times (default: 1).

  -u <user>
      Run the benchmark as this user.  The default depends on the user who
      invoked $_CMD:

          user@host$ $_CMD ...      # default: user
          user@host$ sudo $_CMD ... # default: user
          root@host# $_CMD ...      # default: root

  -q
      Be quiet, don't show benchmark output.
EOF
}

# Print an error, help text, and exit
_usage() {
    _err "$@"
    echo >&2
    _help >&2
    exit $EX_USAGE
}

# Parse positional parameters
_getargs() {
    local min="$1"
    shift

    local args=()
    until [ "$1" = "--" ]; do
        args+=("$1")
        shift
    done
    shift

    if (($# < min)); then
        _usage "Expected %d arguments, got %d (%s)" "$min" $# "$*"
    fi

    local arg
    for arg in "${args[@]}"; do
        if (($#)); then
            local -n ref="$arg"
            ref="$1"
            shift
        fi
    done

    if (($#)); then
        _usage "%d unexpected arguments (%s)" $# "$*"
    fi
}

_args=("${@:0}")
_dir=./results
_runs=1
_user=
_quiet=0

while getopts 'd:nr:u:qh' _opt; do
    case "$_opt" in
        d)
            _dir="$OPTARG"
            ;;
        n)
            _dir=
            ;;
        r)
            _runs="$OPTARG"
            ;;
        u)
            _user="$OPTARG"
            ;;
        q)
            _quiet=1
            ;;
        h)
            _help
            exit
            ;;
        *)
            _help >&2
            exit $EX_USAGE
            ;;
    esac
done

if ((OPTIND > $#)); then
    _usage "No subcommand specified"
fi
_subcmd="${!OPTIND}"
shift $OPTIND

if [ -z "$_dir" ] && ((_quiet)); then
    _usage "-n and -q cannot be combined"
fi

# The default user is the current user, before sudo if used
if [ -z "$_user" ] && [ -n "${SUDO_USER:-}" ]; then
    _user="$SUDO_USER"
fi

case "$_subcmd" in
    run)
        _run "$@"
        ;;
    _bench)
        _bench "$@"
        ;;
    ls)
        _ls_results "$@"
        ;;
    latest)
        _latest "$@"
        ;;
    view)
        _view "$@"
        ;;
    save)
        _save "$@"
        ;;
    clean)
        _clean "$@"
        ;;
    help)
        _help
        ;;
    *)
        _usage "Unknown subcommand %s" "$_subcmd"
        ;;
esac
