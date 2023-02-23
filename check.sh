#!/hint/bash

# Copyright © Tavian Barnes <tavianator@tavianator.com>
# SPDX-License-Identifier: 0BSD

check() {
    printf '%s: ' "$*"
    "$@"
    printf '\n'
}

check-on() {
    if [[ $UNAME =~ $1 ]]; then
        shift
        check "$@"
    fi
}

setup() {
    check ls-cpus
    check ls-cpus all
    check ls-cpus online
    check ls-cpus one-per-core
    for cpu in $(ls-cpus); do
        check ls-cpus same-core "$cpu"
        check ls-cpus same-node "$cpu"
        break
    done
    check-on Linux ls-cpus fast

    echo
    check ls-nodes
    check ls-nodes all
    check ls-nodes online
    for node in $(ls-nodes); do
        check ls-cpus node "$node"
    done

    echo
    if ((UID == 0)); then
        check-on Linux smt-off
        check-on Linux turbo-off
        check-on Linux max-freq
        check aslr-off
    else
        echo "Not running as root, skipping stabilizer tests"
    fi

    export EXPORTED=exported
    UNEXPORTED=unexported
}

bench() {
    [[ $EXPORTED == exported ]]
    [[ ${UNEXPORTED:-} == "" ]]
}
