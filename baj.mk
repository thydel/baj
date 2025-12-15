#!/usr/bin/env -S make -f

MAKEFLAGS += -Rr --warn-undefined-variables
SHELL != which bash
.SHELLFLAGS := -euo pipefail -c

parts := m4 ids emit
ymls := $(parts:%=out/baj-%.yml)
shs := $(ymls:%.yml=%.sh)

cdr = $(filter-out $(firstword $1), $1)

baj.sh: baj.yml bajm.sh; < $<  $(lastword $^) baj:init > $@

#bajm.sh: main := [[ $$\# > 0 ]] && eval baj:"$${@:-pretty}"
bajm.sh: main := eval "$$@"
bajm.sh: baj.mk $(shs); { cat $(call cdr, $^); echo '$(main)'; } | install /dev/stdin $@
.SECONDARY: $(ymls)

ifdef NEVER
out/%.yml: %.md md2yml.jq | out; < $< pandoc -t json | $(lastword $^) | yq -P > $@
%.sh: %.yml bajb.sh; < $< $(lastword $^) > $@
out:; mkdir -p $@
else
out/%.yml: %.md md2yml.jq | out; < $< pandoc -t json | $(lastword $^) | yq -P > $@
out/%.sh: out/%.yml bajb.sh; < $< $(lastword $^) > $@
out:; mkdir -p $@
endif
