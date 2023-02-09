#!/hint/bash

# Copyright © Tavian Barnes <tavianator@tavianator.com>
# SPDX-License-Identifier: 0BSD

# Expand a list like 0,2-3,6-8 into 0 2 3 6 7 8
_split() {
    awk -F, '{
        for (i = 1; i <= NF; ++i) {
            n = split($i, x, /-/);
            start = x[1];
            end = (n > 1) ? x[2] : start;
            for (j = start; j <= end; ++j) {
                print j;
            }
        }
    }'
}

ls-cpus() {
    local which="${1:-online}"

    case "$which" in
        all)
            _split </sys/devices/system/cpu/present
            ;;

        online)
            _split </sys/devices/system/cpu/online
            ;;

        node)
            _split </sys/devices/system/node/node"$2"/cpulist
            ;;

        same-node)
            _split </sys/devices/system/cpu/cpu"$2"/node*/cpulist
            ;;

        same-core)
            # See https://docs.kernel.org/admin-guide/cputopology.html
            # and https://www.kernel.org/doc/Documentation/cputopology.txt
            local file
            file=$(_first_file /sys/devices/system/cpu/cpu"$2"/topology/{core_cpus,thread_siblings}_list)
            _split <"$file"
            ;;

        one-per-core)
            local cpu
            for cpu in $(ls-cpus); do
                # Print the CPU if it's the first of its siblings
                if [ "$(_smt_siblings "$cpu" | head -n1)" = "$cpu" ]; then
                    printf '%d\n' "$cpu"
                fi
            done
            ;;

        fast)
            # The "fast" CPUs for hybrid architectures like big.LITTLE or Alder Lake
            local max=0 cpu freq

            for cpu in $(ls-cpus); do
                freq=$(cat /sys/devices/system/cpu/cpu"$cpu"/cpufreq/cpuinfo_max_freq)
                if ((freq > max)); then
                    max="$freq"
                fi
            done

            for cpu in $(ls-cpus); do
                freq=$(cat /sys/devices/system/cpu/cpu"$cpu"/cpufreq/cpuinfo_max_freq)
                if ((freq == max)); then
                    printf '%d\n' "$cpu"
                fi
            done
            ;;

        *)
            _idkhowto "list $which CPUs"
            ;;
    esac
}

pin-to-cpus() {
    local cpus
    read -ar cpus <<<"$1"
    shift
    taskset -c "$(_join ',' "${cpus[@]}")" "$@"
}

is-cpu-on() {
    local online=/sys/devices/system/cpu/cpu"$1"/online
    [ ! -e "$online" ] || [ "$(cat "$online")" -eq 1 ]
}

cpu-off() {
    set-sysfs /sys/devices/system/cpu/cpu"$1"/online 0
}

ls-nodes() {
    # See https://www.kernel.org/doc/html/latest/admin-guide/mm/numaperf.html

    local which="${1:-online}"

    case "$which" in
        all)
            _split </sys/devices/system/node/present
            ;;

        online)
            _split </sys/devices/system/node/online
            ;;

        *)
            _idkhowto "list $which NUMA nodes"
            ;;
    esac
}

pin-to-nodes() {
    local array
    read -ra array <<< "$1"
    shift

    nodes=$(_join ',' "${array[@]}")
    numactl -m "$nodes" -N "$nodes" -- "$@"
}

turbo-off() {
    local intel_turbo=/sys/devices/system/cpu/intel_pstate/no_turbo
    if [ -e "$intel_turbo" ]; then
        set-sysfs "$intel_turbo" 1
    else
        set-sysfs /sys/devices/system/cpu/cpufreq/boost 0
    fi
}

smt-off() {
    local active=/sys/devices/system/cpu/smt/active
    local control=/sys/devices/system/cpu/smt/control

    if [ "$(cat "$active")" -eq 0 ]; then
        return
    fi

    set-sysfs "$control" off

    # Sometimes the above is enough to disable SMT
    if [ "$(cat "$active")" -eq 0 ]; then
        return
    fi

    # But sometimes, we need to manually offline each sibling thread
    local cpu
    for cpu in $(ls-cpus core); do
        local sibling
        for sibling in $(_smt_siblings "$cpu"); do
            if ((sibling != cpu)); then
                cpu-off "$sibling"
            fi
        done
    done
}

max-freq() {
    local cpu
    for cpu in $(ls-cpus online); do
        local dir=/sys/devices/system/cpu/cpu"$cpu"

        # Set the CPU governor to performance
        local governor="$dir/cpufreq/scaling_governor"
        if [ -e "$governor" ]; then
            set-sysfs "$governor" performance
        fi

        local epp="$dir/cpufreq/energy_performance_preference"
        local epb="$dir/power/energy_perf_bias"
        if [ -e "$epp" ]; then
            # Set the Energy/Performance Preference to performance
            # See https://docs.kernel.org/admin-guide/pm/intel_pstate.html
            set-sysfs "$epp" performance
        elif [ -e "$epb" ]; then
            # Set the Performance and Energy Bias Hint (EPB) to 0 (performance)
            # See https://docs.kernel.org/admin-guide/pm/intel_epb.html
            set-sysfs "$epb" 0
        fi
    done
}
