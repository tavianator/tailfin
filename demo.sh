#!/usr/bin/env bash

setup() {
    # The code in the setup() function runs once before the benchmarks start
    echo "Hello from setup()"

    # To run a command after the benchmarks finish, use atexit:
    atexit echo "Goodbye from setup()"

    # If you make a system-wide change in setup(), it's a good idea to
    # immediately register a command to undo it.  That way even if a later
    # command fails, the change will still be undone.

    # repro comes with a few built-in commands to set common configurations.
    # This command sets CPU frequency scaling to "performance" mode:
    #cpu_freq_max

    # Other possibilities include disabling "turbo boost":
    #turbo_off

    # or turning off SMT (hyperthreading):
    #smt_off
}

bench() {
    echo "Hello from bench()"

    if is_command perf; then
        wrapper="perf stat"
    elif is_command pmc; then
        wrapper="pmc stat"
    else
        wrapper="time"
    fi

    dd if=/dev/zero bs=1M count=4k | $wrapper sha256sum
}
