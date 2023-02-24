#!/hint/bash

# Copyright © Tavian Barnes <tavianator@tavianator.com>
# SPDX-License-Identifier: 0BSD

## Subcommands for managing saved results

# tailfin ls
_ls_results() {
    local dirs=()
    local result
    for result in "$_dir"/????/??/??/??:??:?? "$_dir"/saved/*; do
        if [ -e "$result" ]; then
            dirs+=("$result")
        fi
    done

    ls -d "$@" "${dirs[@]}"
}

# tailfin latest
_latest() {
    if (($#)); then
        _usage "Unexpected arguments '%s'" "$*"
    fi

    local dirs=("$_dir"/????/??/??/??:??:??)
    if [ ! -e "${dirs[0]}" ]; then
        _die $EX_NOINPUT "No results found in %s" "$_dir"
    fi

    printf '%s\n' "${dirs[@]}" | LC_ALL=C sort | tail -n1
}

# tailfin view
_view() {
    local result
    if (($# > 0)); then
        result="$1"
    else
        result=$(_latest)
    fi

    if [ ! -d "$result" ]; then
        _die $EX_NOINPUT "No results found in %s" "$result"
    fi

    find "$result" -type f -print0 | vifm -c 'view!' -
}

# tailfin save
_save() {
    if (($# >= 1)); then
        local target="$_dir/saved/$1"
    else
        _usage "Missing name for saved run"
    fi

    local run
    if (($# >= 2)); then
        run="$2"
    else
        run=$(_latest)
    fi

    if [ -e "$target" ]; then
        _die $EX_CANTCREAT "'%s' already exists" "$target"
    fi

    mkdir -p "$_dir/saved"
    mv -v "$run" "$target"
    chmod -R a-w "$target"
}

# tailfin clean
_clean() {
    local dirs=("$_dir"/????/??/??/??:??:??)
    if [ -e "${dirs[0]}" ]; then
        rm -rI "${dirs[@]}"
    fi
}
