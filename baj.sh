shopt -s expand_aliases
baj:mk-alias () 
{ 
    local id='baj:mk-alias';
    : ${2:?};
    local -n a=BASH_ALIASES;
    if [[ ! -v a[$1] || -v a[$1] && "${a[$1]}" == "$2:${1}$3" ]]; then
        alias $1="$2:${1}$3";
    else
        echo warning $(alias $1) not redefined as "'$2:${1}$3'" 1>&2;
    fi
}
baj:mk-alias asjs baj
baj:asjs () 
{ 
    local id='baj:asjs';
    if test -v Y2J_USE_PYTHON; then
        python3 -c 'import sys, yaml, json; print(json.dumps(yaml.safe_load(sys.stdin.read())))';
    else
        yq -oj "$@";
    fi
}
baj:mk-alias bm4 baj
baj:bm4 () 
{ 
    local id='baj:bm4';
    local jq='def head: "m4_changequote(«,»)m4_changecom()m4_dnl";
def m4: .[][] | to_entries[] | "m4_define(«\(.key)»,«\(.value | @json[1:-1])»)m4_dnl";
def main: if map(has("m4")) | any then group_by(has("m4")) | (last | m4), first end;
head, (inputs | main)';
    jq -nr "$jq" | m4 -P
}
baj:mk-alias dist baj
baj:dist () 
{ 
    local id='baj:dist';
    local jq='def isa:
  def isa:
    if .[1] | not then "alien"
    elif (first | IN("array", "null")) and last == 0 then "root"
    elif first == "array" then "sup"
    else "sub" end;
  def addIsa: has("id") as $id | (.id | [type, $id, length] | isa) as $isa | . + { $isa };
  map(addIsa) | group_by(.isa) | map({ (first.isa): map(del(.isa)) }) | add
  | reduce ("root", "sup") as $i (.; if has($i) | not then .[$i] = [{ id: []}] end);

def useindex: "i";
def addindex: to_entries | map(.value + { (useindex): .key });
def remindex: sort_by(.[useindex]) | map(del(.[useindex]));

def sameType(t): (map(type) | unique) == [t | type];
# merge list of object [ o, ... ]
def merge:
  # merge two objects [ o1, o2 ]
  def merge:
    # merge two values [ v1, v2 ]
    def merge:
      # First is sub, last is sup
      # add lists, sup <- sub otherwise
      if sameType([]) then add | unique else last end;
    # merge all sub values into sup ones
    reduce (first | to_entries)[] as $e (last; .[$e.key] = ([.[$e.key], $e.value] | merge));
  # merge all objects using merge two objects
  reduce .[] as $i ({}; [., $i] | merge);

def check:
  (.sup | map(.id) | add) - (.sub | keys) | unique
  | if length > 0 then "bad id \(@json)\n" | halt_error(1) else empty end;

def main:
  addindex | isa | .sub |= INDEX(.[]; .id)
  | (.sub | keys) as $subs | .root |= map(.id = $subs) | .sub as $sub | .alien as $alien | check
  , reduce (.root + .sup)[] as $sup ($sub; reduce $sup.id[] as $id (.; .[$id] |= ([., ($sup | del(.id))] | merge)))
  | map(.) + $alien | remindex;

main';
    jq -r "$jq"
}
baj:mk-alias emit baj
baj:emit () 
{ 
    local id='baj:emit';
    local jq='def w($s): $s + . + $s;
def q: w("\u0027");
def qq: w("\"");
def at($n): "${@:\($n)}" | qq;

def aliases:
  def is($is): has("is") and IN($is; .is[]);
  def fa: if is("fa") then " " else "" end | @sh;
  .[] | select(has("id") and has("ns")) | "baj:mk-alias \(.id) \(.ns) \(fa)";

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
    jq -r "$jq"
}
baj:mk-alias mk-alias baj
baj:mk-alias () 
{ 
    local id='baj:mk-alias';
    : ${2:?};
    local -n a=BASH_ALIASES;
    if [[ ! -v a[$1] || -v a[$1] && "${a[$1]}" == "$2:${1}$3" ]]; then
        alias $1="$2:${1}$3";
    else
        echo warning $(alias $1) not redefined as "'$2:${1}$3'" 1>&2;
    fi
}
baj:mk-alias pipe baj
baj:pipe () 
{ 
    local id='baj:pipe';
    baj:asjs | baj:bm4 | baj:dist | baj:emit
}
baj:mk-alias header baj
baj:header () 
{ 
    local id='baj:header';
    echo shopt -s expand_aliases;
    declare -f baj:mk-alias
}
baj:mk-alias clean baj
baj:clean () 
{ 
    local id='baj:clean';
    local i;
    for i in ${BASH_ALIASES[@]};
    do
        if [[ $i =~ ${1:?}: ]]; then
            unalias "${i/jqsh:}";
        fi;
    done;
    for i in $(compgen -c $1);
    do
        unset $i;
    done
}
baj:mk-alias main baj
baj:main () 
{ 
    local id='baj:main';
    baj:header;
    baj:pipe
}
baj:mk-alias opts baj ''
baj:mk-alias fail baj ''
baj:mk-alias loop baj ' '
baj:mk-alias list baj ''
baj:mk-alias args baj ' '
baj:mk-alias map baj ' '
baj:mk-alias self baj ''
baj:mk-alias tst baj ''
baj:mk-alias txt1 baj ''
baj:mk-alias txt baj ''
baj:mk-alias nss1 baj ''
baj:mk-alias nss baj ''
baj:mk-alias listid1 baj ''
baj:mk-alias listid baj ''
baj:mk-alias ids1 baj ''
baj:mk-alias ids baj ''
baj:mk-alias fn1 baj ''
baj:mk-alias fn baj ''
baj:mk-alias fns baj ''
baj:mk-alias def1 baj ''
baj:mk-alias def baj ''
baj:mk-alias nsp baj ''
baj:mk-alias aliases baj ''
baj:mk-alias aliases1 baj ''
baj:mk-alias forget baj ''
baj:mk-alias load baj ''
baj:opts () { local ns='baj'; local id='opts'; # Use local -A opts; local args cont; opts "$@" in caller
local opt val tmp i; args=()
until [[ $# -eq 0 ]]; do
    case "$1" in
        --) shift; break;;
        --*=*) opt="${1%%=*}"; val="${1#*=}"; opts["${opt:2}"]="$val"; shift;;
        --*) opts["${1:2}"]="1"; shift;;
        -[0-9]*) args+=("$1"); shift;;
        -) args+=("$1"); shift;;
        -*) tmp=${1:1}
            for ((i = 0; i < ${#tmp}; i++ )); do
                opt="${tmp:$i:1}"
                opts[$opt]=$((opts[$opt] + 1))
            done
            shift;;
        *) args+=("$1"); shift;;
    esac
done; cont=("$@"); }
baj:fail () { local ns='baj'; local id='fail'; unset -v fail; : "${fail:?${FUNCNAME[1]} $@}"; }
baj:loop () { local -a is=('fa'); local ns='baj'; local id='loop'; local i; for i in "${@:2}"; do $1 "$i"; done; }
baj:list () { local ns='baj'; local id='list'; loop echo "$@"; }
baj:args () { local -a is=('fa'); local ns='baj'; local id='args'; mapfile -t; ((${#MAPFILE[@]} > 0)) && "${@:-echo}" "${MAPFILE[@]}"; }
baj:map () { local -a is=('fa'); local ns='baj'; local id='map'; while read; do "${@:-echo}" "$REPLY"; done; }
baj:self () { local ns='baj'; local id='self'; jq "$jq" "$@"; }
baj:tst () { local ns='baj'; local id='tst'; < ${1:?}; }
baj:txt1 () { local ns='baj'; local id='txt1'; header; asjs | bm4 | dist | emit; }
baj:txt () { local ns='baj'; local id='txt'; loop $ns:tst "$@" && cat "$@" | txt1; }
baj:nss1 () { local ns='baj'; local id='nss1'; local jq='.[].ns // empty'; < ${1:?} yq -oj | self -r; }
baj:nss () { local ns='baj'; local id='nss'; loop nss1 "$@"; }
baj:listid1 () { local ns='baj'; local id='listid1'; compgen -c ${1:?}:; compgen -c ns:${1:?}; }
baj:listid () { local ns='baj'; local id='listid'; loop listid1 "$@"; }
baj:ids1 () { local ns='baj'; local id='ids1'; local jq='.[].id'; eval ${1:?} src | jq "$jq" -r; }
baj:ids () { local ns='baj'; local id='ids'; loop ids1 "$@"; }
baj:fn1 () { local ns='baj'; local id='fn1'; listid1 ${1:?} | args declare -f; }
baj:fn () { local ns='baj'; local id='fn'; loop fn1 "$@"; }
baj:fns () { local ns='baj'; local id='fns'; ids "$@" | args def; }
baj:def1 () { local ns='baj'; local id='def1'; [[ -v BASH_ALIASES[${1:?}] ]] || fail $1 not an alias && declare -f ${BASH_ALIASES[$1]}; }
baj:def () { local ns='baj'; local id='def'; loop def1 "$@"; }
baj:nsp () { local ns='baj'; local id='nsp'; compgen -c ns:${1:?} > /dev/null; }
baj:aliases () { local ns='baj'; local id='aliases'; loop aliases1 "$@"; }
baj:aliases1 () { local ns='baj'; local id='aliases1'; local jq='$ARGS.positional | [.[:$n], .[$n:]] | transpose[] | select(last | test("\($ns):")) | first'; nsp ${1:?} || fail not a ns; self -nr --arg ns $1 --argjson n ${#BASH_ALIASES[@]} --args "${!BASH_ALIASES[@]}" "${BASH_ALIASES[@]}"; }
baj:forget () { local ns='baj'; local id='forget'; . <($ns:listid1 ${1:?} | args echo unset -f; nsp $1 && { aliases $1 | args echo unalias; echo unalias $1; }); }
baj:load () { local ns='baj'; local id='load'; forget $(nss "$@"); . <($ns:txt "$@"); }
alias baj=ns:baj; ns:baj () { baj:${1:?} "${@:2}"; }
baj:src () { <<< '[{"ns":"baj","id":"opts","sh":"# Use local -A opts; local args cont; opts \"$@\" in caller\nlocal opt val tmp i; args=()\nuntil [[ $# -eq 0 ]]; do\n    case \"$1\" in\n        --) shift; break;;\n        --*=*) opt=\"${1%%=*}\"; val=\"${1#*=}\"; opts[\"${opt:2}\"]=\"$val\"; shift;;\n        --*) opts[\"${1:2}\"]=\"1\"; shift;;\n        -[0-9]*) args+=(\"$1\"); shift;;\n        -) args+=(\"$1\"); shift;;\n        -*) tmp=${1:1}\n            for ((i = 0; i < ${#tmp}; i++ )); do\n                opt=\"${tmp:$i:1}\"\n                opts[$opt]=$((opts[$opt] + 1))\n            done\n            shift;;\n        *) args+=(\"$1\"); shift;;\n    esac\ndone; cont=(\"$@\")"},{"ns":"baj","id":"fail","sh":"unset -v fail; : \"${fail:?${FUNCNAME[1]} $@}\""},{"is":["fa"],"ns":"baj","id":"loop","sh":"local i; for i in \"${@:2}\"; do $1 \"$i\"; done"},{"ns":"baj","id":"list","sh":"loop echo \"$@\""},{"is":["fa"],"ns":"baj","id":"args","sh":"mapfile -t; ((${#MAPFILE[@]} > 0)) && \"${@:-echo}\" \"${MAPFILE[@]}\""},{"is":["fa"],"ns":"baj","id":"map","sh":"while read; do \"${@:-echo}\" \"$REPLY\"; done"},{"ns":"baj","id":"self","sh":"jq \"$jq\" \"$@\""},{"ns":"baj","id":"tst","sh":"< ${1:?}"},{"ns":"baj","id":"txt1","sh":"header; asjs | bm4 | dist | emit"},{"ns":"baj","id":"txt","sh":"loop $ns:tst \"$@\" && cat \"$@\" | txt1"},{"ns":"baj","id":"nss1","jq":".[].ns // empty","sh":"< ${1:?} yq -oj | self -r"},{"ns":"baj","id":"nss","sh":"loop nss1 \"$@\""},{"ns":"baj","id":"listid1","sh":"compgen -c ${1:?}:; compgen -c ns:${1:?}"},{"ns":"baj","id":"listid","sh":"loop listid1 \"$@\""},{"ns":"baj","id":"ids1","jq":".[].id","sh":"eval ${1:?} src | jq \"$jq\" -r"},{"ns":"baj","id":"ids","sh":"loop ids1 \"$@\""},{"ns":"baj","id":"fn1","sh":"listid1 ${1:?} | args declare -f"},{"ns":"baj","id":"fn","sh":"loop fn1 \"$@\""},{"ns":"baj","id":"fns","sh":"ids \"$@\" | args def"},{"ns":"baj","id":"def1","sh":"[[ -v BASH_ALIASES[${1:?}] ]] || fail $1 not an alias && declare -f ${BASH_ALIASES[$1]}"},{"ns":"baj","id":"def","sh":"loop def1 \"$@\""},{"ns":"baj","id":"nsp","sh":"compgen -c ns:${1:?} > /dev/null"},{"ns":"baj","id":"aliases","sh":"loop aliases1 \"$@\""},{"ns":"baj","id":"aliases1","jq":"$ARGS.positional | [.[:$n], .[$n:]] | transpose[] | select(last | test(\"\\($ns):\")) | first","sh":"nsp ${1:?} || fail not a ns; self -nr --arg ns $1 --argjson n ${#BASH_ALIASES[@]} --args \"${!BASH_ALIASES[@]}\" \"${BASH_ALIASES[@]}\""},{"ns":"baj","id":"forget","sh":". <($ns:listid1 ${1:?} | args echo unset -f; nsp $1 && { aliases $1 | args echo unalias; echo unalias $1; })"},{"ns":"baj","id":"load","sh":"forget $(nss \"$@\"); . <($ns:txt \"$@\")"}]' jq; }
