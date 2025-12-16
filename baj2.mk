#!/usr/bin/env -S make -f

MAKEFLAGS += -Rr --warn-undefined-variables
SHELL != which bash
.SHELLFLAGS := -euo pipefail -c

parts := m4 ids emit
ymls := $(parts:%=out/baj2-%.yml)
shs := $(ymls:%.yml=%.sh)

cdr = $(filter-out $(firstword $1), $1)
ns ?= baj

baj2.sh: head := - { id: null, ns: $(ns) }
baj2.sh: bajm = { echo $(head); cat $(ymls); } | $< $(ns):init
baj2.sh: bajy = < $(lastword $^) $< $(ns):main
baj2.sh: baj2.sh = { $(bajm); $(bajy); } > $@
baj2.sh: bajm2.sh $(yml) baj2.yml; $($@)

bajm2.sh: main := eval "$$@"
bajm2.sh: baj2.mk $(shs); { cat $(call cdr, $^); echo '$(main)'; } | install /dev/stdin $@
.SECONDARY: $(ymls)

out/%.yml: %.md md2yml.jq | out; < $< pandoc -t json | $(lastword $^) | yq -P > $@
out/%.sh: out/%.yml bajb2.sh; < $< $(lastword $^) > $@
out:; mkdir -p $@
