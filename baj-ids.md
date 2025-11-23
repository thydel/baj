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
