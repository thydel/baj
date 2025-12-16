baj:asjs () 
{ 
    local ns=baj;
    local id='asjs';
    if test -v Y2J_USE_PYTHON; then
        python3 -c 'import sys, yaml, json; print(json.dumps(yaml.safe_load(sys.stdin.read())))';
    else
        yq -oj "$@";
    fi
}
baj:clean () 
{ 
    local ns=baj;
    local id='clean';
    local i;
    for i in ${BASH_ALIASES[@]/$ns:clean};
    do
        if [[ $i =~ ${1:?}: ]]; then
            unalias "${i/$ns:}";
        fi;
    done;
    for i in $(compgen -c $1);
    do
        unset $i;
    done
}
baj:emit () 
{ 
    local ns=baj;
    local id='emit';
    local jq='def w($s): $s + . + $s;
def q: w("\u0027");
def qq: w("\"");
def at($n): "${@:\($n)}" | qq;

def aliases:
  def is($is): has("is") and IN($is; .is[]);
  def fa: if is("fa") then " " else "" end | @sh;
  .[] | select(has("id") and has("ns")) | "\($ns):mk-alias \(.id) \(.ns) \(fa)";

def ns:
  map(.ns) | unique[]
  | "alias \(.)=ns:\(.); ns:\(.) () { \(.):${1:?} \("${@:2}" | qq); }";

def ns1:
  map(.ns) | unique[]
  | "alias \(.)=ns:\(.); ns:\(.) () { \(.):${1:?} \(at(2) | qq); }";

def is_sh_var:
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

def tail:
  group_by(.ns) | map("\(first.ns):src () { <<< \(. | @json | @sh) jq; }")[];

aliases, funs, ns, tail';
    jq -r "$jq" --arg ns $ns
}
baj:header () 
{ 
    local ns=baj;
    local id='header';
    echo shopt -s expand_aliases;
    declare -f $ns:mk-alias
}
baj:init () 
{ 
    local ns=baj;
    local id='init';
    $ns:header;
    $ns:asjs | $ns:dist | $ns:emit
}
baj:main () 
{ 
    local ns=baj;
    local id='main';
    $ns:header;
    $ns:asjs | $ns:bm4 | $ns:dist | $ns:emit
}
baj:mk-alias () 
{ 
    local ns=baj;
    local id='mk-alias';
    : ${2:?};
    local -n a=BASH_ALIASES;
    if [[ ! -v a[$1] || -v a[$1] && "${a[$1]}" == "$2:${1}$3" ]]; then
        alias $1="$2:${1}$3";
    else
        echo warning $(alias $1) not redefined as "'$2:${1}$3'" 1>&2;
    fi
}
