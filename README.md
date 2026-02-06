# baj — Bash function libraries, compiled from YAML/Markdown

baj is a compiler that turns declarative sources (YAML, Markdown) into
a **single self-contained Bash script** — sourceable, executable, and
streamable over SSH without copying files.

```bash
source <(curl -fsSL https://raw.githubusercontent.com/thydel/baj/2025-12-22-a/cmd/baj.sh)
path:addp ~/bin
```

## Why functions, not scripts

A Bash function lives in memory. Unlike a script, it can be:

- serialized with `declare -f`
- transmitted over a pipe
- evaluated by a remote shell with zero filesystem footprint

baj exploits this: the unit of work is the **function**, not the file.
A set of functions can be selected, serialized, and streamed:

```bash
with-lib path git2md -- gr2md | ssh host bash
```

Nothing is installed. Nothing persists. The remote shell evaluates
functions from stdin, runs them, and exits.

## Why jq as the engine

jq is typically used to query JSON. baj uses it as a **general-purpose
transformation language** across the entire pipeline:

- **Parse**: Pandoc AST (JSON) → structured function records
- **Classify**: tag each record as `sub`, `sup`, `root`, or `alien`
- **Inherit**: deep-merge superclass records into subclasses (scalars
  override, arrays concatenate) — declarative OOP on plain data
- **Emit**: lower function records into Bash source (`ns:fun () { ... }`,
  aliases, variables, namespace helpers)

jq also appears **inside** generated functions. A YAML key `jq:` becomes
a `local jq='...'` variable, and the function body calls `jq "$jq"` —
the function carries its own jq program as data.

## The pipeline

```
YAML / Markdown
      │
      ▼
  asjs (yq)          → flat JSON array of objects
      │
      ▼
  bm4 (jq → m4 -P)  → textual macro expansion (before inheritance)
      │
      ▼
  dist (jq)          → classification + deep-merge inheritance
      │
      ▼
  emit (jq)          → Bash functions, aliases, namespace helpers
```

m4 runs **before** inheritance so expanded text is inherited like any
other value. Macros use French guillemets (`« »`) as quotes and are
namespace-prefixed — no accidental expansion.

## Aliases as compilation

Bash resolves aliases at **parse time**, not execution time. baj uses
this as a source-level indirection:

- YAML sources use short names: `addp`
- baj generates `alias addp=path:addp`
- when Bash parses the output, `addp` is replaced by `path:addp`
- the final in-memory code contains **only qualified names**

This means you can change a function's namespace without editing its
source. Aliases are a compilation mechanism, not sugar.

## Dual execution

The same generated file works two ways because it ends with `eval "$@"`:

| Mode | Usage | What happens |
|------|-------|-------------|
| Library | `source baj.sh` | Functions and aliases loaded into current shell |
| Command | `./baj.sh path:addp ~/bin` | Arguments evaluated as a function call |

## Bootstrap

baj compiles itself in two stages:

1. **Core** (`baj:init`) — `baj-boot.sh` (hand-written, no macros)
   reads `baj-core.md` (literate Bash+jq in Markdown). This produces
   the core functions: `baj:asjs`, `baj:bm4`, `baj:dist`, `baj:emit`.

2. **Library** (`baj:main`) — the core processes `baj-lib.yml`
   **through its own pipeline** (including m4), producing the full
   `bajl:*` toolkit: `load`, `with-lib`, `as-cmd`, `nss`, etc.

The core cannot use m4 (it defines the m4 processor). The library uses
m4 freely. This breaks the circular dependency.

## A concrete example

**Input** — `lib/path.yml`:
```yaml
- id:
  ns: path
- id:
  sh: ': ${1:?}; PATH=$(jq "$jq" -nr --args "$@")'
- m4:
    EP: '(env.PATH / ":") as $p'
- id: addp
  jq: 'EP | ($ARGS.positional - $p) + $p | join(":")'
- id: delp
  jq: 'EP | $p - $ARGS.positional | join(":")'
```

**Output** — `cmd/path.sh` (after `make`):
```bash
path:addp () {
    local jq='(env.PATH / ":") as $p
              | ($ARGS.positional - $p) + $p | join(":")';
    : ${1:?}; PATH=$(jq "$jq" -nr --args "$@")
}
```

What happened:
- `EP` was m4-expanded into the jq expression
- The root `sh:` (with no `id`) was distributed to both `addp` and `delp`
- `jq:` became `local jq='...'`
- The function calls `jq "$jq"` directly — running its own jq program against `$PATH`

## From one-liner to tool

Consider idempotent PATH editing. In jq:

```jq
env.PATH / ":" | . - ["/home/thy/bin"] + ["/home/thy/bin"] | join(":")
```

Split on `:`, remove then prepend — idempotency falls out of array
semantics. No edge-case string matching, no regex. Call it twice, same
result.

This is a powerful one-liner, but it's not directly *usable*. The
classic Bash alternative — `case ":$PATH:" in *:"$1":*) ;;` — works
but can't express set operations this cleanly. A Python script would
handle it trivially but adds a runtime dependency disproportionate to
the task.

baj sits in the sweet spot: it turns that jq expression into a
callable, self-contained tool with no dependency beyond bash and jq
(both ubiquitous). The YAML source declares the jq program, baj
compiles it into a function that **carries its own jq logic as data**:

```bash
source path.sh
path:addp ~/bin       # idempotent — safe to call repeatedly
path:delp ~/old/bin   # same mechanism, different jq expression
```

The function runs jq internally, captures the result, assigns it to
`$PATH`. Two lines of YAML produced a reusable, composable, SSH-streamable
tool — from a one-liner that would otherwise live in someone's dotfiles
and never be shared.

## Functions vs subshells

`./path.sh path:addp ~/bin` runs in command mode — but it can't
work. A script runs in a subshell: `PATH` is modified in the child
process and lost when it exits. Only sourced functions operate in the
current shell:

```bash
source path.sh
path:addp ~/bin    # modifies PATH in the current shell
```

This is the classic argument for bags of functions over scripts.
A script is an isolated world; a sourced function is a tool that
acts on your environment.

## Transparent generation

baj functions carry their own resolved source. You can inspect
exactly what the generator produced — after inheritance, after m4
expansion:

```console
$ source path.sh
$ path src | yq -P
- sh: ': ${1:?}; PATH=$(jq "$jq" -nr --args "$@")'
  ns: path
  id: addp
  jq: (env.PATH / ":") as $p | ($ARGS.positional - $p) + $p | join(":")
- sh: ': ${1:?}; PATH=$(jq "$jq" -nr --args "$@")'
  ns: path
  id: delp
  jq: (env.PATH / ":") as $p | $p - $ARGS.positional | join(":")
```

Both `addp` and `delp` received the shared `sh:` body from
inheritance. `EP` was expanded into the full jq expression. Nothing
is opaque — the transformations are traceable, the output is readable.
This makes baj closer to a **templating tool** than a traditional
compiler: it generates code you can read, understand, and trust.

## What's next

- Pipeline details: the four stages in depth (asjs, bm4, dist, emit)
- Authoring guide: writing YAML/Markdown sources, the inheritance model
- Library reference: included libraries (path, git2md, mdq, parsarg, llmfs, baj-ansible)
- `with-lib`: function selection and zero-copy remote execution
