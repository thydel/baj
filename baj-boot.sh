baj-boot-asjs () {
    if test -v Y2J_USE_PYTHON;
    then python3 -c 'import sys, yaml, json; print(json.dumps(yaml.safe_load(sys.stdin.read())))';
    else yq -oj "$@"; fi
}

baj-boot-emit () {
    jq=''
    jq+='def var: "local \(.key)=\(.value | @sh)";'
    jq+='def vars: del(.sh) | to_entries | map(var) | join("; ");'
    jq+='def fun: select(has("id")) | "\(.id) () { \(vars); \(.sh // true); }";'
    jq+='.[] | fun'
    jq -r "$jq"
}

baj-boot-load () { source <(< ${1:?} baj-boot-asjs | baj-boot-emit); }
baj-boot-ini () { for i in m4 ids mini; do baj-boot-load baj-$i.yml; done; }
