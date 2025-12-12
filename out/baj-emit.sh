baj-asjs () 
{ 
    local id='baj-asjs';
    if test -v Y2J_USE_PYTHON; then
        python3 -c 'import sys, yaml, json; print(json.dumps(yaml.safe_load(sys.stdin.read())))';
    else
        yq -oj "$@";
    fi
}
baj-emit () 
{ 
    local id='baj-emit';
    local jq='def is_sh_var:
   def iterable: type | IN("array", "object");
.value | (iterable | not) or (map(.) | unique | map(iterable | not) | all);

def js_var: "local \(.key)=\(.value | @json | @sh)";
def sh_array_var: "local -a \(.key)=(\(.value | map(@sh) | join(" ")))";
def sh_map_var: .key as $k | .value | to_entries | map(map(@sh)[]) | join(" ") | "local -A \($k)=(\(.))";

def sh_var:
  (.value | type) as $t
  | if $t == "array" then sh_array_var
    elif $t == "object" then sh_map_var
    else "local \(.key)=\(.value | @sh)" end;

def var: if is_sh_var then sh_var else js_var end;
def vars: del(.sh) | to_entries | map(var) | join("; ");

def funs: .[] | if has("id") then "\(.ns):\(.id) () { \(vars); \(.sh); }" end;
def aliases: .[] | select([has("id", "sh")] | all) | "baj-mk-alias \(.id) \(.ns)";

aliases, funs';
    jq -r "$jq"
}
baj-head () 
{ 
    local id='baj-head';
    declare -f baj-mk-alias
}
baj-mk-alias () 
{ 
    local id='baj-mk-alias';
    : ${2:?};
    local -n a=BASH_ALIASES;
    if [[ ! -v a[$1] || -v a[$1] && ${a[$1]} == $2:$1 ]]; then
        alias $1="$2:${1}$3";
    else
        echo warning $(alias $1) not redefined as $2:$1 1>&2;
    fi
}
baj-pipe () 
{ 
    local id='baj-pipe';
    baj-head;
    baj-asjs | baj-m4 | baj-ids | baj-emit
}
baj-pretty () 
{ 
    local id='baj-pretty';
    { 
        echo shopt -s expand_aliases;
        baj-pipe;
        echo declare -f
    } | bash
}
