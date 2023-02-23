#!/hint/bash

# Copyright © Tavian Barnes <tavianator@tavianator.com>
# SPDX-License-Identifier: 0BSD

## Command line parsing

_help() {
    cat <<EOF
Usage: $_CMD [-d DIR | -n] [-r RUNS] [-u USER] [-q] [-h] SCRIPT [ARGS...]

  -d DIR
      Set the directory for results and logs (default: ./results).  The current
      date and time will be appended to this path to distinguish runs.

  -n
      Don't save benchmark logs

  -r RUNS
      Run the benchmark this many times (default: 1).

  -u USER
      Run the benchmark as this user.  The default depends on the user who
      invoked $_CMD:

          user@host$ $_CMD ...      # default: user
          user@host$ sudo $_CMD ... # default: user
          root@host# $_CMD ...      # default: root

  -q
      Be quiet, don't show benchmark output.

  -h
      This help message.

  SCRIPT
      The benchmark script to invoke.

  ARGS
      Arguments to pass to the benchmark script.
EOF
}

_usage() {
    _err "$@"
    _help >&2
    exit $EX_USAGE
}

_args=("$0" "$@")
_dir=./results
_runs=1
_user=
_quiet=0
_bench=0

while getopts 'd:nr:u:qxh' opt; do
    case "$opt" in
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
        x)
            _bench=1
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

if [ -z "$_dir" ] && ((_quiet)); then
    _usage "-n and -q cannot be combined"
fi

# The default user is the current user, before sudo if used
if [ -z "$_user" ] && [ -n "${SUDO_USER:-}" ]; then
    _user="$SUDO_USER"
fi

if ((OPTIND > $#)); then
    _usage "No script specified"
fi
_script="${!OPTIND}"
shift $OPTIND
