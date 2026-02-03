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

ns ?= baj

install = install --backup=t /dev/stdin $@

cmd/baj.sh: cmd/%.sh : out/%.sh $(self) | cmd
 source $<
 as-cmd $* $*l | $(install)

libs := git-to-md baj-ansible path mdq llmfs-mini llmfs-core
libs: phony $(libs:%=cmd/%.sh)

cmd/%.sh: lib/%.yml cmd/baj.sh
 source $(lastword $^)
 load $<
 nss $< | args as-cmd | $(install)

[ := out/baj-core.sh baj-lib.yml
] := out/baj.sh
$]: baj-core = < $*-core.md $*-boot.sh md2yml | out/$*-core.sh $(ns):init
$]: baj-lib = < $*-lib.yml out/$*-core.sh $(ns):main
$]: $] = { $(baj-core); $(baj-lib); }
$]: out/%.sh : $[; $($@) | install --backup=t /dev/stdin $@

out/baj-core.sh: baj-boot.sh baj-core.md | out; < $(lastword $^) $< md2sh | install --backup=t /dev/stdin $@

out cmd:; mkdir -p $@

bin := /usr/local/bin
cmds := baj $(libs) with
installed := $(cmds:%=$(bin)/%.sh)
install: phony $(installed)
$(bin)/%.sh: cmd/%.sh; install $< $@

# Local Variables:
# Mode: GNUmakefile
# indent-tabs-mode: nil
# End:
