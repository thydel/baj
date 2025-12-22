#!/usr/bin/env -S bash

declare -A jq=()

self () { jq "${jq[${FUNCNAME[1]}]}" "$@"; }

jq[header]='[{ id, ns: "\($ns)" }] + input'
header () { self -n --arg ns ${ns:-baj}; }

jq[md2js]='
def txt: .c[2] | map(.c // " ") | join("");
def f($b):
  if $b.t == "Header" then ($b | txt) as $h |
    if $h | startswith("id ") then . + [{id: $h[3:]}] else . + [null] end
  elif $b.t == "CodeBlock" and .[-1] then
    .[-1][$b.c[0][1][0] // "txt"] = $b.c[1]
  end;
.blocks | reduce .[] as $b ([]; f($b)) | map(values)'
md2js () { pandoc -t json | self | header; }

jq[js2sh]='
def var: "local \(.key)=\(.value | @sh)";
def vars: del(.id, .sh) | to_entries | map(var);
def body: vars + [ .sh // true ] | join("; ");
def fun: select(.id) | "\($ns):\(.id) () { \(body); }";
.[] | fun'
js2sh () { self -r --arg ns ${ns:-baj}; }

js2yml () { yq -P; }
md2yml () { md2js | js2yml; }
md2sh () { md2js | js2sh; echo 'eval "$@"'; }
sh2sh () { { md2sh; echo declare -f; } | bash; }

eval "$@"
