#!/hint/bash

# Copyright © Tavian Barnes <tavianator@tavianator.com>
# SPDX-License-Identifier: 0BSD

ls-cpus() {
    local which="${1:-online}"

    case "$which" in
        all|online)
            sysctl -n kern.sched.topology_spec \
                | xmllint --xpath 'groups/group/cpu/text()' - \
                | sed 's/, */ /g'
            ;;

        node)
            cpuset -d "$2" -g | sed 's/.*: //; s/, */ /g'
            ;;

        same-node)
            local node
            node=$(sysctl -n dev.cpu."$2".%domain 2>/dev/null || printf 0)
            ls-cpus node "$node"
            ;;

        same-core)
            sysctl -n kern.sched.topology_spec \
                | xmllint --xpath '//group[flags/flag[@name="SMT"]]/cpu/text()' - \
                | sed -n "/\<$2\>/s/, */ /gp"
            ;;

        one-per-core)
            sysctl -n kern.sched.topology_spec \
                | xmllint --xpath '//group[flags/flag[@name="SMT"]]/cpu/text()' - \
                | sed 's/,.*//'
            ;;

        *)
            _idkhowto "list $which CPUs"
            ;;
    esac
}

is-cpu-on() {
    ls-cpus online | grep "^$1\$"
}

pin-to-cpus() {
    local cpus=$(_implode <<< "$1")
    shift
    cpuset -l "$cpus" -- "$@"
}

ls-nodes() {
    local nodes
    nodes=$(sysctl -n vm.ndomains)
    seq 0 $((nodes - 1))
}

pin-to-nodes() {
    local nodes=$(_implode <<< "$1")
    shift
    cpuset -n "$nodes" -- "$@"
}

smt-off() {
    local threads
    threads=$(sysctl -n kern.smp.threads_per_core)
    if [ "$threads" -ne 1 ]; then
        # TODO
        _idkhowto "turn SMT off"
    fi
}

max-freq() {
    # Set the Intel Energy/Performance Preference to 0 (performance)
    # See intel_pstate(4)
    local ctl
    for ctl in $(ls-sysctls 'dev.hwpstate_intel.*.epp'); do
        set-sysctl "$ctl" 0
    done
}

aslr-off() {
    # See https://wiki.freebsd.org/AddressSpaceLayoutRandomization
    local ctl
    for ctl in kern.elf{32,64}.aslr.{,pie_}enable; do
        set-sysctl "$ctl" 0
    done
}
