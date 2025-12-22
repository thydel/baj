baj:bm4 () { local jq='def head: "m4_changequote(«,»)m4_changecom()m4_dnl";
def m4: .[][] | to_entries[] | "m4_define(«\(.key)»,«\(.value | @json[1:-1])»)m4_dnl";
def main: if map(has("m4")) | any then group_by(has("m4")) | (last | m4), first end;
head, (inputs | main)'; jq -nr "$jq" | m4 -P; }
baj:dist () { local jq='def isa:
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
baj:asjs () { if test -v Y2J_USE_PYTHON;
then python3 -c 'import sys, yaml, json; print(json.dumps(yaml.safe_load(sys.stdin.read())))';
else yq -oj "$@"; fi; }
baj:mk-alias () { : ${2:?}
local -n a=BASH_ALIASES;
if [[ ! -v a[$1] || -v a[$1] && "${a[$1]}" == "$2:${1}$3" ]];
then alias $1="$2:${1}$3";
else echo warning $(alias $1) not redefined as "'$2:${1}$3'" >&2;
fi; }
baj:emit () { local jq='def w($s): $s + . + $s;
def q: w("\u0027");
def qq: w("\"");
def at: "$@" | qq;
def at($n): "${@:\($n)}" | qq;

def is($is): has("is") and IN($is; .is[]);

def ky: map(select([has("ky", "is")] | all)) | map(map(.) | combinations);
def byky: ky | group_by(first) | map({ (first | first): map(last) }) | add;
def byis: ky | group_by(last) | map({ (first | last): map(first) }) | add;

def aliases:
  def fa: if is("fa") then " " else "" end | @sh;
  .in[] | select(has("id") and has("ns")) | "\($ns):mk-alias \(.id) \(.ns) \(fa)";

def noalias: .in[] | select(is("na")) | "unalias \(.id)";

def ns:
  .in | map(.ns) | unique[]
  | "alias \(.)=ns:\(.); ns:\(.) () { \(.):${1:?} \(at(2)); }";

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
def novars($kys): (null | { sh, ns, id, is } | keys + $kys.nv) as $k | del(.[$k[]]);
#def novars($kys): del(.sh, .ns, .id, .is, .tt);
def vars($kys): novars($kys) | to_entries | map(var);

def sh: .sh // "self \(at)";
def body($kys): vars($kys) + [sh] | join("; ");

def funs:
  .kys as $kys
  | .in[] | select(has("id")) | "\(.ns):\(.id) () { \(body($kys)); }";

def src: .in | group_by(.ns) | map("\(first.ns):src () { <<< \(. | @json | @sh) jq; }")[];

{ in: ., kys: byis } | aliases, funs, ns, noalias, src'; jq -r "$jq" --arg ns ${FUNCNAME%%:*}; }
baj:clean () { local ns=${FUNCNAME%%:*}
local i; for i in ${BASH_ALIASES[@]/$ns:clean}; do if [[ $i =~ ${1:?}: ]] then unalias "${i/$ns:}"; fi; done
for i in $(compgen -c $1); do unset $i; done; }
baj:header () { echo shopt -s expand_aliases; declare -f ${FUNCNAME%%:*}:mk-alias; }
baj:init () { local ns=${FUNCNAME%%:*}
$ns:header; $ns:asjs | $ns:dist | $ns:emit; }
baj:main () { local ns=${FUNCNAME%%:*}
$ns:header; $ns:asjs | $ns:bm4 | $ns:dist | $ns:emit; }
eval "$@"
