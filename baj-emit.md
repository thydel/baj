# id baj:asjs

```sh
if test -v Y2J_USE_PYTHON;
then python3 -c 'import sys, yaml, json; print(json.dumps(yaml.safe_load(sys.stdin.read())))';
else yq -oj "$@"; fi
```

# id baj:mk-alias

```sh
: ${2:?}
local -n a=BASH_ALIASES;
if [[ ! -v a[$1] || -v a[$1] && "${a[$1]}" == "$2:${1}$3" ]];
then alias $1="$2:${1}$3";
else echo warning $(alias $1) not redefined as "'$2:${1}$3'" >&2;
fi
```

# id baj:emit

```jq
def w($s): $s + . + $s;
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

aliases, funs, ns, tail
```

```sh
jq -r "$jq"
```

# id baj:pipe

```sh
baj:asjs | baj:bm4 | baj:dist | baj:emit
```

# id baj:clean

```sh
local i; for i in ${BASH_ALIASES[@]}; do if [[ $i =~ ${1:?}: ]] then unalias "${i/jqsh:}"; fi; done
for i in $(compgen -c $1); do unset $i; done
```

# id baj:sys

```sh
local funs=(asjs bm4 dist emit mk-alias pipe header clean main)
local fun; for fun in ${funs[@]}; do echo baj:mk-alias $fun baj; declare -f baj:$fun; done
```

# id baj:header

```sh
echo shopt -s expand_aliases; declare -f baj:mk-alias
```

# id baj:init

```sh
baj:header; baj:sys; baj:pipe
```

# id baj:main

```sh
baj:header; baj:pipe
```

