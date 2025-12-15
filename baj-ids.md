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

# Classification Logic

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

# id baj:dist

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
