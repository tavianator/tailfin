#!/usr/bin/env tailfin

setup() {
    # The code in the setup() function runs once before the benchmarks start
    echo "Hello from setup()"
    echo

    # To run a command after the benchmarks finish, use at-exit:
    at-exit echo "Goodbye from setup()"

    # To pass a variable from setup() to bench(), export it to the environment
    export SIZE=$((4 * 1024 * 1024 * 1024))

    # tailfin comes with a few built-in commands to set common configurations.
    # Uncomment one or more of the lines below to test their effect on benchmark
    # stability.  (You will probably have to run tailfin with sudo once you do.)

    #turbo-off	# Disable "turbo boost"
    #smt-off	# Disable SMT (hyperthreading)
    #max-freq	# Set CPU frequency scaling to "performance" mode
}

bench() {
    echo "Hello from bench()"
    echo

    # Exported variables from setup() are visible here
    echo "SIZE: $SIZE"
    echo

    if is-command perf; then
        wrapper="perf stat"
    elif is-command pmc; then
        wrapper="pmc stat"
    else
        wrapper="time"
    fi

    head -c$SIZE /dev/zero | $wrapper sha256sum
}
