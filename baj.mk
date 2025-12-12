#!/usr/bin/env -S make -f

parts := m4 ids emit
ymls := $(parts:%=out/baj-%.yml)
shs := $(ymls:%.yml=%.sh)

bajm.sh: $(shs); { cat $^; echo 'eval "$${@:-baj-pipe}"'; } | install /dev/stdin $@
.SECONDARY: $(ymls)

out/%.yml: %.md md2yml.jq | out; < $< pandoc -t json | $(lastword $^) | yq -P > $@
%.sh: %.yml bajb.sh; < $< $(lastword $^) > $@
out:; mkdir -p $@
