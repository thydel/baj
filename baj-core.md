# Macros expansion using m4

## id bm4

The `bm4` function serves as a preprocessor that converts JSON input
streams into `m4(1)` macro definitions. It is designed to safely
handle the transition from structured data to template expansion.

The process begins with the `head` function, which configures the
`m4(1)` environment. It changes the default quote characters to French
guillemets and disables comment processing. This safety step prevents
standard shell or JSON characters like hash marks or double quotes
from being misinterpreted by the `m4(1)` parser.

The core transformation logic resides in the `m4` function. This
function flattens the input array and iterates through every key-value
pair. For each pair, it generates a definition string. A crucial part
of this step is the use of a specific `jq(1)` filter, `@json[1:-1]`,
that sanitizes the value by stripping its outer quotes while escaping
internal characters, ensuring the content is safely embedded into the
macro definition.

Finally, the `main` function orchestrates the output stream. It splits
the input into two groups: those containing macro definitions and
those containing template content. It reorders these groups to ensure
all definitions are emitted before the template content that relies on
them. The result is piped into `m4(1)` with the prefix flag enabled to
enforce namespace safety.

```jq
def head: "m4_changequote(«,»)m4_changecom()m4_dnl";
def m4: .[][] | to_entries[] | "m4_define(«\(.key)»,«\(.value | @json[1:-1])»)m4_dnl";
def main: if map(has("m4")) | any then group_by(has("m4")) | (last | m4), first end;
head, (inputs | main)
```

```sh
jq -nr "$jq" | m4 -P
```

# Distribution model

This script processes a flat array of objects by treating them as a
class hierarchy.  It implements a "distribution" model: data from
"superclasses" (`sup`) is merged down into the "subclasses" (`sub`)
they reference via an ID list.

The process is as follows:

1. Classify all input objects into roles (`sub`, `sup`, `root`,
   `alien`).
2. Validate relationships between `sup` and `sub` objects.
3. Perform a conditional deep merge: a `sup` value is only added if
   the key is new in the `sub` object, unless both values are arrays,
   in which case they are concatenated and uniquified.

The final output is the enriched list of `sub` objects (plus any
`alien` objects), with the original order preserved.

## Classification Logic

The classification is determined by the type and content of each
object's `id` field.

Assuming the input is a YAML array of objects:

- `sub`: Has a scalar `id` (e.g., a string or number).
- `sup`: Has a non-empty array `id` (referencing one or more `sub`
  objects).
- `root`: Has an empty array `id` (`[]`) or a `null` `id`.  It acts as
         a special `sup` whose data is distributed to all `sub`
         objects.
- `alien`: Has no `id` field.

For example:

```yaml
- id: sub_item_1       # -> Becomes a "sub"
  data: ...
- id: ["sub_item_1"]   # -> Becomes a "sup"
  info: ...
- id: []               # -> Becomes a "root"
  config: ...
- name: "orphan"       # -> Becomes an "alien"
  note: ...
```

## id dist

```jq
def isa:
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

main
```

```sh
jq -r "$jq"
```

# Generate bash functions

## id asjs

```sh
if test -v Y2J_USE_PYTHON;
then python3 -c 'import sys, yaml, json; print(json.dumps(yaml.safe_load(sys.stdin.read())))';
else yq -oj "$@"; fi
```

## id mk-alias

```sh
: ${2:?}
local -n a=BASH_ALIASES;
if [[ ! -v a[$1] || -v a[$1] && "${a[$1]}" == "$2:${1}$3" ]];
then alias $1="$2:${1}$3";
else echo warning $(alias $1) not redefined as "'$2:${1}$3'" >&2;
fi
```

## id emit

```jq
def w($s): $s + . + $s;
def q: w("\u0027");
def qq: w("\"");
def at($n): "${@:\($n)}" | qq;

def aliases:
  def is($is): has("is") and IN($is; .is[]);
  def fa: if is("fa") then " " else "" end | @sh;
  .[] | select(has("id") and has("ns")) | "\($ns):mk-alias \(.id) \(.ns) \(fa)";

def ns:
  map(.ns) | unique[]
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
def vars: del(.sh) | to_entries | map(var) | join("; ");

def funs: .[] | if has("id") then "\(.ns):\(.id) () { \(vars); \(.sh); }" end;

def tail:
  group_by(.ns) | map("\(first.ns):src () { <<< \(. | @json | @sh) jq; }")[];

aliases, funs, ns, tail
```

```sh
jq -r "$jq" --arg ns $ns
```

## id clean

```sh
local i; for i in ${BASH_ALIASES[@]/$ns:clean}; do if [[ $i =~ ${1:?}: ]] then unalias "${i/$ns:}"; fi; done
for i in $(compgen -c $1); do unset $i; done
```

## id header

```sh
echo shopt -s expand_aliases; declare -f $ns:mk-alias
```

## id init

```sh
$ns:header; $ns:asjs | $ns:dist | $ns:emit
```

## id main

```sh
$ns:header; $ns:asjs | $ns:bm4 | $ns:dist | $ns:emit
```
