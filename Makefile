#!/usr/bin/env -S make -f

MAKEFLAGS += -Rr --warn-undefined-variables
SHELL != which bash
.SHELLFLAGS := -euo pipefail -c

.ONESHELL:
.DELETE_ON_ERROR:

ns ?= baj

[ := out/baj-core.sh baj-lib.yml
] := out/baj.sh
$]: baj = < $*-core.md $*-boot.sh md2yml | out/$*-core.sh $(ns):init
$]: baj-lib = < $*-lib.yml out/$*-core.sh $(ns):main
$]: $] = { $(baj); $(baj-lib); }
$]: out/%.sh : $[; $($@) > $@

out/baj-core.sh: baj-boot.sh baj-core.md; < $(lastword $^) $< md2sh | install /dev/stdin $@
