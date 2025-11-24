#!/usr/bin/env -S make -f

baj-m4.sh: baj-m4.md md2yml.jq baj-boot.sh
	< $< pandoc -t json | md2yml.jq | baj-boot.sh baj-boot-emit | { cat; echo declare -f baj-m4; } | bash > $@

baj-m4.yml: baj-m4.md md2yml.jq; @< $< pandoc -t json | md2yml.jq | yq -P
