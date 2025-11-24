# id baj-m4

The `baj-m4` function serves as a preprocessor that converts JSON
input streams into `m4(1)` macro definitions. It is designed to safely
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
