#!/usr/bin/env -S make -f

MAKEFLAGS += -Rr --warn-undefined-variables
SHELL != which bash
.SHELLFLAGS := -euo pipefail -c

_WS := $(or ) $(or )
_comma := ,
.RECIPEPREFIX := $(_WS)

.ONESHELL:
.DELETE_ON_ERROR:
.PHONY: phony
self := $(firstword $(MAKEFILE_LIST))

install = install --backup=t /dev/stdin $@

mdq != type -p mdq.sh

main: phony cmd/parsarg.sh

out/%.yml: %.md $(mdq) | out; < $< m4 -P | $(lastword $^) md2yml | $(install)
.PRECIOUS: out/%.yml

cmd/%.sh: out/%.yml | cmd
 source baj.sh
 load $<
 nss $< | args as-cmd | $(install)

out cmd:; mkdir -p $@

# Local Variables:
# indent-tabs-mode: nil
# End:
