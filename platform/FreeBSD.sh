#!/hint/bash

# Copyright © Tavian Barnes <tavianator@tavianator.com>
# SPDX-License-Identifier: 0BSD

ls-cpus() {
    local which="${1:-online}"

    case "$which" in
        all|online)
            sysctl -n kern.sched.topology_spec \
                | xmllint --xpath 'groups/group/cpu/text()' - \
                | sed 's/, */\n/g'
            ;;

        core)
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
    local cpus="$1"
    shift
    cpuset -l "$(_join ',' $cpus)" -- "$@"
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
