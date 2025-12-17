shopt -s expand_aliases
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
baj:mk-alias bm4 baj ''
baj:mk-alias dist baj ''
baj:mk-alias asjs baj ''
baj:mk-alias mk-alias baj ''
baj:mk-alias emit baj ''
baj:mk-alias clean baj ''
baj:mk-alias header baj ''
baj:mk-alias init baj ''
baj:mk-alias main baj ''
baj:bm4 () { local ns='baj'; local id='bm4'; local jq='def head: "m4_changequote(«,»)m4_changecom()m4_dnl";
def m4: .[][] | to_entries[] | "m4_define(«\(.key)»,«\(.value | @json[1:-1])»)m4_dnl";
def main: if map(has("m4")) | any then group_by(has("m4")) | (last | m4), first end;
head, (inputs | main)'; jq -nr "$jq" | m4 -P; }
baj:dist () { local ns='baj'; local id='dist'; local jq='def isa:
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

main'; jq -r "$jq"; }
baj:asjs () { local ns='baj'; local id='asjs'; if test -v Y2J_USE_PYTHON;
then python3 -c 'import sys, yaml, json; print(json.dumps(yaml.safe_load(sys.stdin.read())))';
else yq -oj "$@"; fi; }
baj:mk-alias () { local ns='baj'; local id='mk-alias'; : ${2:?}
local -n a=BASH_ALIASES;
if [[ ! -v a[$1] || -v a[$1] && "${a[$1]}" == "$2:${1}$3" ]];
then alias $1="$2:${1}$3";
else echo warning $(alias $1) not redefined as "'$2:${1}$3'" >&2;
fi; }
baj:emit () { local ns='baj'; local id='emit'; local jq='def w($s): $s + . + $s;
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

aliases, funs, ns, tail'; jq -r "$jq" --arg ns $ns; }
baj:clean () { local ns='baj'; local id='clean'; local i; for i in ${BASH_ALIASES[@]/$ns:clean}; do if [[ $i =~ ${1:?}: ]] then unalias "${i/$ns:}"; fi; done
for i in $(compgen -c $1); do unset $i; done; }
baj:header () { local ns='baj'; local id='header'; echo shopt -s expand_aliases; declare -f $ns:mk-alias; }
baj:init () { local ns='baj'; local id='init'; $ns:header; $ns:asjs | $ns:dist | $ns:emit; }
baj:main () { local ns='baj'; local id='main'; $ns:header; $ns:asjs | $ns:bm4 | $ns:dist | $ns:emit; }
alias baj=ns:baj; ns:baj () { baj:${1:?} "${@:2}"; }
baj:src () { <<< '[{"ns":"baj","id":"bm4","jq":"def head: \"m4_changequote(«,»)m4_changecom()m4_dnl\";\ndef m4: .[][] | to_entries[] | \"m4_define(«\\(.key)»,«\\(.value | @json[1:-1])»)m4_dnl\";\ndef main: if map(has(\"m4\")) | any then group_by(has(\"m4\")) | (last | m4), first end;\nhead, (inputs | main)","sh":"jq -nr \"$jq\" | m4 -P"},{"ns":"baj","id":"dist","jq":"def isa:\n  def isa:\n    if .[1] | not then \"alien\"\n    elif (first | IN(\"array\", \"null\")) and last == 0 then \"root\"\n    elif first == \"array\" then \"sup\"\n    else \"sub\" end;\n  def addIsa: has(\"id\") as $id | (.id | [type, $id, length] | isa) as $isa | . + { $isa };\n  map(addIsa) | group_by(.isa) | map({ (first.isa): map(del(.isa)) }) | add\n  | reduce (\"root\", \"sup\") as $i (.; if has($i) | not then .[$i] = [{ id: []}] end);\n\ndef useindex: \"i\";\ndef addindex: to_entries | map(.value + { (useindex): .key });\ndef remindex: sort_by(.[useindex]) | map(del(.[useindex]));\n\ndef sameType(t): (map(type) | unique) == [t | type];\n# merge list of object [ o, ... ]\ndef merge:\n  # merge two objects [ o1, o2 ]\n  def merge:\n    # merge two values [ v1, v2 ]\n    def merge:\n      # First is sub, last is sup\n      # add lists, sup <- sub otherwise\n      if sameType([]) then add | unique else last end;\n    # merge all sub values into sup ones\n    reduce (first | to_entries)[] as $e (last; .[$e.key] = ([.[$e.key], $e.value] | merge));\n  # merge all objects using merge two objects\n  reduce .[] as $i ({}; [., $i] | merge);\n\ndef check:\n  (.sup | map(.id) | add) - (.sub | keys) | unique\n  | if length > 0 then \"bad id \\(@json)\\n\" | halt_error(1) else empty end;\n\ndef main:\n  addindex | isa | .sub |= INDEX(.[]; .id)\n  | (.sub | keys) as $subs | .root |= map(.id = $subs) | .sub as $sub | .alien as $alien | check\n  , reduce (.root + .sup)[] as $sup ($sub; reduce $sup.id[] as $id (.; .[$id] |= ([., ($sup | del(.id))] | merge)))\n  | map(.) + $alien | remindex;\n\nmain","sh":"jq -r \"$jq\""},{"ns":"baj","id":"asjs","sh":"if test -v Y2J_USE_PYTHON;\nthen python3 -c '\''import sys, yaml, json; print(json.dumps(yaml.safe_load(sys.stdin.read())))'\'';\nelse yq -oj \"$@\"; fi"},{"ns":"baj","id":"mk-alias","sh":": ${2:?}\nlocal -n a=BASH_ALIASES;\nif [[ ! -v a[$1] || -v a[$1] && \"${a[$1]}\" == \"$2:${1}$3\" ]];\nthen alias $1=\"$2:${1}$3\";\nelse echo warning $(alias $1) not redefined as \"'\''$2:${1}$3'\''\" >&2;\nfi"},{"ns":"baj","id":"emit","jq":"def w($s): $s + . + $s;\ndef q: w(\"\\u0027\");\ndef qq: w(\"\\\"\");\ndef at($n): \"${@:\\($n)}\" | qq;\n\ndef aliases:\n  def is($is): has(\"is\") and IN($is; .is[]);\n  def fa: if is(\"fa\") then \" \" else \"\" end | @sh;\n  .[] | select(has(\"id\") and has(\"ns\")) | \"\\($ns):mk-alias \\(.id) \\(.ns) \\(fa)\";\n\ndef ns:\n  map(.ns) | unique[]\n  | \"alias \\(.)=ns:\\(.); ns:\\(.) () { \\(.):${1:?} \\(\"${@:2}\" | qq); }\";\n\ndef ns1:\n  map(.ns) | unique[]\n  | \"alias \\(.)=ns:\\(.); ns:\\(.) () { \\(.):${1:?} \\(at(2) | qq); }\";\n\ndef is_sh_var:\n   def iterable: type | IN(\"array\", \"object\");\n.value | (iterable | not) or (map(.) | unique | map(iterable | not) | all);\n\ndef js_var: \"local \\(.key)=\\(.value | @json | @sh)\";\ndef sh_array_var: \"local -a \\(.key)=(\\(.value | map(@sh) | join(\" \")))\";\ndef sh_map_var: .key as $k | .value | to_entries | map(map(@sh)[]) | join(\" \") | \"local -A \\($k)=(\\(.))\";\n\ndef sh_var:\n  (.value | type) as $t\n  | if $t == \"array\" then sh_array_var\n    elif $t == \"object\" then sh_map_var\n    else \"local \\(.key)=\\(.value | @sh)\" end;\n\ndef var: if is_sh_var then sh_var else js_var end;\ndef vars: del(.sh) | to_entries | map(var) | join(\"; \");\n\ndef funs: .[] | if has(\"id\") then \"\\(.ns):\\(.id) () { \\(vars); \\(.sh); }\" end;\n\ndef tail:\n  group_by(.ns) | map(\"\\(first.ns):src () { <<< \\(. | @json | @sh) jq; }\")[];\n\naliases, funs, ns, tail","sh":"jq -r \"$jq\" --arg ns $ns"},{"ns":"baj","id":"clean","sh":"local i; for i in ${BASH_ALIASES[@]/$ns:clean}; do if [[ $i =~ ${1:?}: ]] then unalias \"${i/$ns:}\"; fi; done\nfor i in $(compgen -c $1); do unset $i; done"},{"ns":"baj","id":"header","sh":"echo shopt -s expand_aliases; declare -f $ns:mk-alias"},{"ns":"baj","id":"init","sh":"$ns:header; $ns:asjs | $ns:dist | $ns:emit"},{"ns":"baj","id":"main","sh":"$ns:header; $ns:asjs | $ns:bm4 | $ns:dist | $ns:emit"}]' jq; }
shopt -s expand_aliases
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
baj:mk-alias opts bajl ''
baj:mk-alias fail bajl ''
baj:mk-alias loop bajl ' '
baj:mk-alias list bajl ''
baj:mk-alias args bajl ' '
baj:mk-alias map bajl ' '
baj:mk-alias self bajl ''
baj:mk-alias tst bajl ''
baj:mk-alias txt bajl ''
baj:mk-alias txt1 bajl ''
baj:mk-alias nss bajl ''
baj:mk-alias nss1 bajl ''
baj:mk-alias listid bajl ''
baj:mk-alias listid1 bajl ''
baj:mk-alias ids bajl ''
baj:mk-alias ids1 bajl ''
baj:mk-alias fn bajl ''
baj:mk-alias fn1 bajl ''
baj:mk-alias fns bajl ''
baj:mk-alias def bajl ''
baj:mk-alias def1 bajl ''
baj:mk-alias ns bajl ''
baj:mk-alias nsp bajl ''
baj:mk-alias aliases bajl ''
baj:mk-alias aliases1 bajl ''
baj:mk-alias forget bajl ''
baj:mk-alias forget1 bajl ''
baj:mk-alias load bajl ''
baj:mk-alias warn bajl ''
baj:mk-alias optal bajl ''
baj:mk-alias prudent bajl ''
baj:mk-alias exp bajl ''
baj:mk-alias lib1 bajl ''
baj:mk-alias lib bajl ''
baj:mk-alias with-lib bajl ''
baj:mk-alias as-lib bajl ''
baj:mk-alias as-cmd bajl ''
bajl:opts () { local ns='bajl'; local id='opts'; # Use local -A opts; local args cont; opts "$@" in caller
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
bajl:fail () { local ns='bajl'; local id='fail'; unset -v fail; : "${fail:?${FUNCNAME[1]} $@}"; }
bajl:loop () { local -a is=('fa'); local ns='bajl'; local id='loop'; local i; for i in "${@:2}"; do $1 "$i"; done; }
bajl:list () { local ns='bajl'; local id='list'; loop echo "$@"; }
bajl:args () { local -a is=('fa'); local ns='bajl'; local id='args'; mapfile -t; ((${#MAPFILE[@]} > 0)) && "${@:-echo}" "${MAPFILE[@]}"; }
bajl:map () { local -a is=('fa'); local ns='bajl'; local id='map'; while read; do "${@:-echo}" "$REPLY"; done; }
bajl:self () { local ns='bajl'; local id='self'; jq "$jq" "$@"; }
bajl:tst () { local ns='bajl'; local id='tst'; < ${1:?}; }
bajl:txt () { local ns='bajl'; local id='txt'; loop $ns:tst "$@" && cat "$@" | txt1; }
bajl:txt1 () { local ns='bajl'; local id='txt1'; header; asjs | bm4 | dist | emit; }
bajl:nss () { local ns='bajl'; local id='nss'; loop nss1 "$@"; }
bajl:nss1 () { local ns='bajl'; local id='nss1'; local jq='.[].ns // empty'; < ${1:?} yq -oj | self -r; }
bajl:listid () { local ns='bajl'; local id='listid'; loop listid1 "$@"; }
bajl:listid1 () { local ns='bajl'; local id='listid1'; compgen -c ${1:?}:; compgen -c ns:${1:?}; }
bajl:ids () { local ns='bajl'; local id='ids'; loop ids1 "$@"; }
bajl:ids1 () { local ns='bajl'; local id='ids1'; local jq='.[].id'; eval ${1:?} src | jq "$jq" -r; }
bajl:fn () { local ns='bajl'; local id='fn'; loop fn1 "$@"; }
bajl:fn1 () { local ns='bajl'; local id='fn1'; listid1 ${1:?} | args declare -f; }
bajl:fns () { local ns='bajl'; local id='fns'; ids "$@" | args def; }
bajl:def () { local ns='bajl'; local id='def'; loop def1 "$@"; }
bajl:def1 () { local ns='bajl'; local id='def1'; [[ -v BASH_ALIASES[${1:?}] ]] || fail $1 not an alias && declare -f ${BASH_ALIASES[$1]}; }
bajl:ns () { local ns='bajl'; local id='ns'; (($# == 0)) || fail too many args; compgen -c ns: | cut -d: -f2; }
bajl:nsp () { local ns='bajl'; local id='nsp'; compgen -c ns:${1:?} > /dev/null; }
bajl:aliases () { local ns='bajl'; local id='aliases'; loop aliases1 "$@"; }
bajl:aliases1 () { local ns='bajl'; local id='aliases1'; local jq='$ARGS.positional | [.[:$n], .[$n:]] | transpose[] | select(last | test("\($ns):")) | first'; nsp ${1:?} || fail not a ns; self -nr --arg ns $1 --argjson n ${#BASH_ALIASES[@]} --args "${!BASH_ALIASES[@]}" "${BASH_ALIASES[@]}"; }
bajl:forget () { local ns='bajl'; local id='forget'; loop forget1 "$@"; }
bajl:forget1 () { local ns='bajl'; local id='forget1'; . <($ns:listid1 ${1:?} | args echo unset -f; nsp $1 && { aliases $1 | args echo unalias; echo unalias $1; }); }
bajl:load () { local ns='bajl'; local id='load'; forget $(nss "$@"); . <($ns:txt "$@"); }
bajl:warn () { local ns='bajl'; local id='warn'; echo \# generated by $ns:${FUNCNAME[1]}, avoid edit; }
bajl:optal () { local ns='bajl'; local id='optal'; echo shopt -s expand_aliases; }
bajl:prudent () { local ns='bajl'; local id='prudent'; echo set -euo pipefail; echo shopt -s inherit_errexit; }
bajl:exp () { local ns='bajl'; local id='exp'; listid ${1:?} | args echo export -f; }
bajl:lib1 () { local ns='bajl'; local id='lib1'; nsp ${1:?} || fail not a ns; alias $1; alias $(aliases $1); fn $1; }
bajl:lib () { local ns='bajl'; local id='lib'; optal; loop lib1 "$@"; def self; exp "$@"; }
bajl:with-lib () { local ns='bajl'; local id='with-lib'; (($#)) || fail $id; optal; until [[ $# == 0 || $1 == -- ]]; do lib1 $1; shift; done; [[ $1 == -- ]] && shift; def self; (($#)) && { f=${BASH_ALIASES[$1]:-$1}; shift; echo $f "${@@Q}"; }; }
bajl:as-lib () { local ns='bajl'; local id='as-lib'; warn; lib "$@"; }
bajl:as-cmd () { local ns='bajl'; local id='as-cmd'; as-lib "$@"; echo 'eval "$@"'; }
alias bajl=ns:bajl; ns:bajl () { bajl:${1:?} "${@:2}"; }
bajl:src () { <<< '[{"ns":"bajl","id":"opts","sh":"# Use local -A opts; local args cont; opts \"$@\" in caller\nlocal opt val tmp i; args=()\nuntil [[ $# -eq 0 ]]; do\n    case \"$1\" in\n        --) shift; break;;\n        --*=*) opt=\"${1%%=*}\"; val=\"${1#*=}\"; opts[\"${opt:2}\"]=\"$val\"; shift;;\n        --*) opts[\"${1:2}\"]=\"1\"; shift;;\n        -[0-9]*) args+=(\"$1\"); shift;;\n        -) args+=(\"$1\"); shift;;\n        -*) tmp=${1:1}\n            for ((i = 0; i < ${#tmp}; i++ )); do\n                opt=\"${tmp:$i:1}\"\n                opts[$opt]=$((opts[$opt] + 1))\n            done\n            shift;;\n        *) args+=(\"$1\"); shift;;\n    esac\ndone; cont=(\"$@\")"},{"ns":"bajl","id":"fail","sh":"unset -v fail; : \"${fail:?${FUNCNAME[1]} $@}\""},{"is":["fa"],"ns":"bajl","id":"loop","sh":"local i; for i in \"${@:2}\"; do $1 \"$i\"; done"},{"ns":"bajl","id":"list","sh":"loop echo \"$@\""},{"is":["fa"],"ns":"bajl","id":"args","sh":"mapfile -t; ((${#MAPFILE[@]} > 0)) && \"${@:-echo}\" \"${MAPFILE[@]}\""},{"is":["fa"],"ns":"bajl","id":"map","sh":"while read; do \"${@:-echo}\" \"$REPLY\"; done"},{"ns":"bajl","id":"self","sh":"jq \"$jq\" \"$@\""},{"ns":"bajl","id":"tst","sh":"< ${1:?}"},{"ns":"bajl","id":"txt","sh":"loop $ns:tst \"$@\" && cat \"$@\" | txt1"},{"ns":"bajl","id":"txt1","sh":"header; asjs | bm4 | dist | emit"},{"ns":"bajl","id":"nss","sh":"loop nss1 \"$@\""},{"ns":"bajl","id":"nss1","jq":".[].ns // empty","sh":"< ${1:?} yq -oj | self -r"},{"ns":"bajl","id":"listid","sh":"loop listid1 \"$@\""},{"ns":"bajl","id":"listid1","sh":"compgen -c ${1:?}:; compgen -c ns:${1:?}"},{"ns":"bajl","id":"ids","sh":"loop ids1 \"$@\""},{"ns":"bajl","id":"ids1","jq":".[].id","sh":"eval ${1:?} src | jq \"$jq\" -r"},{"ns":"bajl","id":"fn","sh":"loop fn1 \"$@\""},{"ns":"bajl","id":"fn1","sh":"listid1 ${1:?} | args declare -f"},{"ns":"bajl","id":"fns","sh":"ids \"$@\" | args def"},{"ns":"bajl","id":"def","sh":"loop def1 \"$@\""},{"ns":"bajl","id":"def1","sh":"[[ -v BASH_ALIASES[${1:?}] ]] || fail $1 not an alias && declare -f ${BASH_ALIASES[$1]}"},{"ns":"bajl","id":"ns","sh":"(($# == 0)) || fail too many args; compgen -c ns: | cut -d: -f2"},{"ns":"bajl","id":"nsp","sh":"compgen -c ns:${1:?} > /dev/null"},{"ns":"bajl","id":"aliases","sh":"loop aliases1 \"$@\""},{"ns":"bajl","id":"aliases1","jq":"$ARGS.positional | [.[:$n], .[$n:]] | transpose[] | select(last | test(\"\\($ns):\")) | first","sh":"nsp ${1:?} || fail not a ns; self -nr --arg ns $1 --argjson n ${#BASH_ALIASES[@]} --args \"${!BASH_ALIASES[@]}\" \"${BASH_ALIASES[@]}\""},{"ns":"bajl","id":"forget","sh":"loop forget1 \"$@\""},{"ns":"bajl","id":"forget1","sh":". <($ns:listid1 ${1:?} | args echo unset -f; nsp $1 && { aliases $1 | args echo unalias; echo unalias $1; })"},{"ns":"bajl","id":"load","sh":"forget $(nss \"$@\"); . <($ns:txt \"$@\")"},{"ns":"bajl","id":"warn","sh":"echo \\# generated by $ns:${FUNCNAME[1]}, avoid edit"},{"ns":"bajl","id":"optal","sh":"echo shopt -s expand_aliases"},{"ns":"bajl","id":"prudent","sh":"echo set -euo pipefail; echo shopt -s inherit_errexit"},{"ns":"bajl","id":"exp","sh":"listid ${1:?} | args echo export -f"},{"ns":"bajl","id":"lib1","sh":"nsp ${1:?} || fail not a ns; alias $1; alias $(aliases $1); fn $1"},{"ns":"bajl","id":"lib","sh":"optal; loop lib1 \"$@\"; def self; exp \"$@\""},{"ns":"bajl","id":"with-lib","sh":"(($#)) || fail $id; optal; until [[ $# == 0 || $1 == -- ]]; do lib1 $1; shift; done; [[ $1 == -- ]] && shift; def self; (($#)) && { f=${BASH_ALIASES[$1]:-$1}; shift; echo $f \"${@@Q}\"; }"},{"ns":"bajl","id":"as-lib","sh":"warn; lib \"$@\""},{"ns":"bajl","id":"as-cmd","sh":"as-lib \"$@\"; echo '\''eval \"$@\"'\''"}]' jq; }
