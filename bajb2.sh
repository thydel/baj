#!/usr/bin/env -S bash

asjs () {
    if test -v Y2J_USE_PYTHON;
    then python3 -c 'import sys, yaml, json; print(json.dumps(yaml.safe_load(sys.stdin.read())))';
    else yq -oj "$@"; fi
}

emit () {
    jq=''
    jq+='def ns: "local ns=\($ns)";'
    jq+='def var: "local \(.key)=\(.value | @sh)";'
    jq+='def vars: del(.sh) | to_entries | map(var) | join("; ");'
    jq+='def fun: select(has("id")) | "\($ns):\(.id) () { \(ns); \(vars); \(.sh // true); }";'
    jq+='.[] | fun'
    asjs | jq -r "$jq" --arg ns $ns
}

pretty () { { emit; echo declare -f; } | bash; }

ns=${1:-baj}; shift; eval "${@:-pretty}"
