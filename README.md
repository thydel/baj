**Declarative Bash function libraries, compiled to one file and streamable over SSH**

<!-- markdown-toc-generate-toc -->
<!-- https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=1036359 -->
<!--
< README.md pandoc -f gfm -t gfm --toc --toc-depth=6 --template doc/toc.md --columns=196 | grep -v Table.of.Contents
-->

-   [What is baj?](#what-is-baj)
-   [Core idea](#core-idea)
-   [One-file usage](#one-file-usage)
-   [Dual usage model](#dual-usage-model)
    -   [1. Library / REPL mode](#1-library--repl-mode)
    -   [2. Command mode](#2-command-mode)
-   [Namespaces and aliases](#namespaces-and-aliases)
    -   [Why this matters](#why-this-matters)
-   [Zero-copy remote execution (key feature)](#zero-copy-remote-execution-key-feature)
-   [Why `eval "$@"` is deliberate](#why-eval--is-deliberate)
-   [How baj works (high level)](#how-baj-works-high-level)
-   [What baj is good at](#what-baj-is-good-at)
-   [Design principles](#design-principles)
-   [Status](#status)
-   [A note on aliases (important)](#a-note-on-aliases-important)
    -   [Source-level indirection](#source-level-indirection)
    -   [Why this matters](#why-this-matters-1)
    -   [Summary](#summary)

# What is baj?

**baj** is a toolchain that lets you write Bash function libraries *declaratively* (using YAML and Markdown), compile them into **pure Bash**, and use them:

* interactively (REPL-style),
* as command-line tools,
* or remotely over SSH **without copying files**.

> **To use baj, you only need one file:**
> `baj.sh`

No installation, no packaging, no deployment on remote nodes.

---

# Core idea

baj treats **shell functions as data**:

* functions are *described*, not handwritten
* composition and inheritance happen before code generation
* the final output is a **self-contained Bash script**

That script can be:

* `source`d,
* executed directly,
* or streamed into a remote shell.

---

# One-file usage

All baj functionality is contained in a **single generated file**:

```sh
source baj.sh
```

That’s it.

Once sourced, all namespaces, functions, aliases, and helpers are available in memory.

This property is intentional and fundamental to baj’s design.

---

# Dual usage model

A baj-generated file is designed to work in **two complementary ways**, without modification.

---

## 1. Library / REPL mode

When sourced:

```sh
source baj.sh
```

You get an interactive, namespaced function environment:

* functions are available as `ns:function`
* short aliases are also available (see below)
* namespaces can be loaded, inspected, and cleaned explicitly

Example:

```sh
git2md:gr2md
gr2md   # alias
path:addp ~/bin
```

This mode is ideal for:

* exploration
* diagnostics
* interactive administration
* composition of tools

---

## 2. Command mode

The *same file* can also be executed:

```sh
./baj.sh ns:function arg1 arg2
```

This works because baj-generated files end with:

```sh
eval "$@"
```

In this mode:

* the file behaves like a dispatcher
* arguments are interpreted as a function call
* no persistent environment is required

This enables use as:

* a CLI tool
* part of pipelines
* a remote command payload

---

# Namespaces and aliases

Every function in baj belongs to a namespace and is generated as:

```
ns:function
```

For convenience, baj **also generates a matching alias**:

```
function = ns:function
```

Example:

```sh
git2md:gr2md
gr2md        # alias to git2md:gr2md
```

## Why this matters

* avoids global name collisions
* keeps namespaces explicit
* preserves ergonomic, short commands
* makes interactive and scripted usage equally pleasant

Aliases are created and cleaned in a controlled, namespace-aware way.

---

# Zero-copy remote execution (key feature)

A central design goal of baj is:

> **Run coherent sets of shell functions remotely without copying files.**

Because baj emits:

* pure Bash
* no filesystem assumptions
* no runtime state
* only ubiquitous tools (`bash`, `jq`, `sed`, `awk`, `perl`, `make`, standard Unix commands)

you can do:

```sh
with-lib git2md path -- gr2md |
ssh host bash
```

What happens:

1. required functions are emitted to stdout
2. they are evaluated by the remote shell
3. execution happens immediately
4. nothing is installed or persisted

This is **zero-copy, zero-state execution**.

---

# Why `eval "$@"` is deliberate

Using:

```sh
eval "$@"
```

is not a shortcut — it is a **core enabler**:

* one artifact acts as both library and command
* functions remain first-class
* execution can be streamed
* SSH usage becomes trivial

This choice is what allows baj to blur the line between:

* sourcing,
* executing,
* and remote evaluation.

---

# How baj works (high level)

```
YAML / Markdown
      ↓
Pandoc (AST → JSON)
      ↓
jq (semantic transforms, inheritance)
      ↓
m4 (safe, controlled macro expansion)
      ↓
Pure Bash (functions + aliases)
```

Each stage is explicit, inspectable, and reproducible.

---

# What baj is good at

* reusable shell function libraries
* namespaced Bash APIs
* declarative configuration + behavior
* ephemeral automation
* SSH fan-out without deployment
* literate shell tooling

---

# Design principles

* **One file to consume**
* **Functions over scripts**
* **Streaming over installation**
* **Declarative over imperative**
* **Ephemeral execution over state**
* **Ubiquitous tools only**

---

# Status

baj is intentionally low-level and explicit.
It is meant to be composed, inspected, and adapted — not hidden behind magic.

---

# A note on aliases (important)

Aliases in baj are **not only a convenience for interactive use**.

They play a key role **at source time**.

---

## Source-level indirection

When writing YAML or Markdown sources, you can refer to a function using its **short name**:

```sh
fun
```

even though the generated function will be:

```sh
ns:fun
```

This works because:

* baj generates `alias fun=ns:fun`
* Bash resolves aliases **while reading**, not while executing
* the emitted Bash source always contains the **fully qualified name**

As a result:

* the final generated code never depends on aliases
* aliases are eliminated during shell parsing
* the emitted source is explicit and unambiguous

---

## Why this matters

This gives baj an important property:

> **You can change a function’s namespace without rewriting its sources.**

Because:

* source files use short names
* namespace resolution happens via aliases
* generated code always uses `ns:fun`

This enables:

* easy refactoring of namespaces
* reuse of the same Markdown/YAML across different libraries
* late binding of namespaces without textual rewrites

---

## Summary

* aliases exist at **parse time**, not runtime
* generated Bash contains only `ns:fun`
* short names are a stable authoring interface
* namespaces remain explicit in the output

This is why aliases are part of baj’s compilation model, not an afterthought.

---
