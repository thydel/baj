baj:bm4 () 
{ 
    local id='baj:bm4';
    local jq='def head: "m4_changequote(«,»)m4_changecom()m4_dnl";
def m4: .[][] | to_entries[] | "m4_define(«\(.key)»,«\(.value | @json[1:-1])»)m4_dnl";
def main: if map(has("m4")) | any then group_by(has("m4")) | (last | m4), first end;
head, (inputs | main)';
    jq -nr "$jq" | m4 -P
}
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
baj:asjs () 
{ 
    local id='baj:asjs';
    if test -v Y2J_USE_PYTHON; then
        python3 -c 'import sys, yaml, json; print(json.dumps(yaml.safe_load(sys.stdin.read())))';
    else
        yq -oj "$@";
    fi
}
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
baj:header () 
{ 
    local id='baj:header';
    echo shopt -s expand_aliases;
    declare -f baj:mk-alias
}
baj:init () 
{ 
    local id='baj:init';
    baj:header;
    baj:sys;
    baj:pipe
}
baj:main () 
{ 
    local id='baj:main';
    baj:header;
    baj:pipe
}
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
baj:pipe () 
{ 
    local id='baj:pipe';
    baj:asjs | baj:bm4 | baj:dist | baj:emit
}
baj:sys () 
{ 
    local id='baj:sys';
    local funs=(asjs bm4 dist emit mk-alias pipe header clean main);
    local fun;
    for fun in ${funs[@]};
    do
        echo baj:mk-alias $fun baj;
        declare -f baj:$fun;
    done
}
eval "$@"
