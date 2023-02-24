# Copyright © Tavian Barnes <tavianator@tavianator.com>
# SPDX-License-Identifier: 0BSD

check:
	shellcheck -a ./tailfin
	./tailfin -n run check.sh

.PHONY: check
