**Architecture of baj**

This document explains how **baj** transforms declarative sources into executable Bash, and why the pipeline is structured the way it is.

The emphasis is on:

* data flow
* transformation order
* design constraints
* properties that enable zero-copy execution and refactoring

---

<!-- markdown-toc-generate-toc -->
<!-- https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=1036359 -->
<!--
< architecture.md pandoc -f gfm -t gfm --toc --toc-depth=6 --template toc.md --columns=196 | grep -v Table.of.Contents
-->

-   [Overview](#overview)
-   [Design constraints (non-negotiable)](#design-constraints-non-negotiable)
-   [Stage 1 — Markdown / YAML → JSON](#stage-1--markdown--yaml--json)
    -   [Purpose](#purpose)
    -   [How](#how)
    -   [Result](#result)
-   [Stage 2 — Textual expansion (m4)](#stage-2--textual-expansion-m4)
    -   [Purpose](#purpose-1)
    -   [Why this comes early](#why-this-comes-early)
    -   [Safety model](#safety-model)
-   [Stage 3 — Semantic processing (jq)](#stage-3--semantic-processing-jq)
    -   [Function model](#function-model)
    -   [Classification](#classification)
    -   [Inheritance and distribution](#inheritance-and-distribution)
    -   [Why jq](#why-jq)
-   [Stage 4 — Bash emission](#stage-4--bash-emission)
    -   [Purpose](#purpose-2)
    -   [What is generated](#what-is-generated)
-   [Aliases as a compilation mechanism](#aliases-as-a-compilation-mechanism)
    -   [Parse-time resolution](#parse-time-resolution)
    -   [Why this matters](#why-this-matters)
-   [Dual execution model](#dual-execution-model)
    -   [Library / REPL mode](#library--repl-mode)
    -   [Command mode](#command-mode)
-   [Zero-copy remote execution](#zero-copy-remote-execution)
-   [Summary](#summary)

# Overview

At a high level, baj is a **compiler**:

* input: YAML and Markdown
* output: pure Bash
* execution model: `source`, `eval`, or streaming to `bash`

The pipeline is intentionally simple, linear, and inspectable.

```
YAML / Markdown
      ↓
Pandoc (AST → JSON)
      ↓
m4 (textual expansion)
      ↓
jq (classification, inheritance, composition)
      ↓
Bash emission
```

Each stage has a clearly defined responsibility.

---

# Design constraints (non-negotiable)

The architecture is shaped by the following constraints:

1. **Pure Bash output**

   * no runtime beyond Bash
   * no generated dependencies

2. **One-file consumption**

   * everything must live in a single script
   * suitable for `source` or stdin

3. **Zero-copy remote execution**

   * no files transferred
   * no installation
   * no persistent state

4. **Ubiquitous tooling only**

   * `bash`, `jq`, `sed`, `awk`, `perl`, `make`, standard Unix commands

These constraints explain many design choices that might otherwise look unusual.

---

# Stage 1 — Markdown / YAML → JSON

## Purpose

Turn human-oriented documents into **structured data**.

## How

* Markdown is processed with `pandoc -t json`
* YAML is parsed and normalized
* code blocks, headers, and metadata are preserved

## Result

A JSON representation that:

* preserves document structure
* keeps code blocks intact
* can be reasoned about programmatically

At this stage:

* no semantics are applied
* no inheritance exists
* no code generation happens

---

# Stage 2 — Textual expansion (m4)

## Purpose

Perform **pure textual expansion** before any semantic reasoning.

## Why this comes early

Some transformations:

* are purely textual
* are inconvenient or impossible in jq
* must happen *before* inheritance to avoid duplication or ambiguity

By running `m4` early:

* expansions participate naturally in inheritance
* expanded content is treated like native source
* no post-merge textual rewriting is required

---

## Safety model

baj uses `m4` in a **strictly constrained way**:

* custom quotes (`« »`)
* comments disabled
* macros are explicitly namespaced
* no implicit expansion

This avoids classic `m4` hazards while retaining its expressive power.

---

# Stage 3 — Semantic processing (jq)

This is the core of baj.

At this stage, **functions are treated as data**.

---

## Function model

Each function definition is represented as a record containing (conceptually):

* `id`   — function name
* `ns`   — namespace
* `sh`   — shell body
* optional metadata (`is`, `ky`, `jq`, etc.)

jq never emits Bash directly; it reasons about these records.

---

## Classification

Definitions are classified into semantic roles, for example:

* **sub**   — concrete functions
* **sup**   — inherited fragments
* **root**  — defaults
* **alien** — pass-through data

This classification controls how definitions participate in inheritance.

---

## Inheritance and distribution

Inheritance is declarative and data-driven.

Rules (conceptual):

* scalars: sub overrides sup
* arrays: concatenation with deduplication
* objects: deep merge
* order is deterministic

Because `m4` already ran:

* inherited content is fully expanded
* no macro re-evaluation is required
* the merge operates on final text

---

## Why jq

jq is used because it:

* is ubiquitous
* is purely functional
* makes data flow explicit
* produces deterministic output

jq enforces a strict separation between:

* *what a function is*
* *how it is emitted*

---

# Stage 4 — Bash emission

## Purpose

Lower structured data into **explicit Bash code**.

## What is generated

For each namespace:

* Bash functions: `ns:function`
* aliases: `function=ns:function`
* variables (scalars, arrays, associative)
* namespace helpers:

  * loaders
  * cleanup functions
  * source emitters

The generated code is:

* explicit
* readable
* self-contained

No alias is required at runtime for correctness.

---

# Aliases as a compilation mechanism

Aliases in baj are **not only for ergonomics**.

They are part of the compilation model.

---

## Parse-time resolution

Bash resolves aliases **while reading**, not during execution.

baj leverages this property:

* sources (YAML / Markdown) may refer to `fun`
* baj generates `alias fun=ns:fun`
* when Bash reads the generated script:

  * `fun` is replaced with `ns:fun`
* the final parsed code contains **only fully qualified names**

As a result:

* aliases do not exist semantically in the output
* generated Bash never depends on aliases
* `ns:fun` is always explicit

---

## Why this matters

This enables:

* namespace refactoring without touching sources
* reuse of the same source under different namespaces
* late binding of `ns` values
* stable authoring using short names

Aliases are thus a **source-level indirection**, not runtime sugar.

---

# Dual execution model

The emitted Bash file supports two execution styles.

---

## Library / REPL mode

```sh
source baj.sh
```

* functions are loaded into the shell
* aliases improve ergonomics
* namespaces can be cleaned explicitly

This is ideal for long-lived shells.

---

## Command mode

```sh
./baj.sh ns:function arg…
```

This works because the file ends with:

```sh
eval "$@"
```

This allows:

* immediate execution
* pipeline integration
* SSH streaming

---

# Zero-copy remote execution

Because the output is:

* pure Bash
* self-contained
* filesystem-independent

it can be streamed:

```sh
with-lib ns1 ns2 -- fun |
ssh host bash
```

No files are copied.
No state is created.

This property drives many architectural decisions upstream.

---

# Summary

baj’s architecture is shaped by a small set of strong constraints:

* declarative sources
* explicit transformations
* pure Bash output
* streamable execution

The result is a system where:

* documentation is executable
* refactoring is cheap
* deployment disappears
* functions become the unit of distribution

---

If you want, next natural docs would be:

* `docs/namespaces.md` (lifecycle, cleanup, aliasing rules)
* `docs/with-lib.md` (selection and streaming semantics)
* `docs/source-model.md` (YAML/MD authoring rules)

But architecturally, this document now tells the full story.
Perfect — here is a **full `docs/architecture.md` draft**, consistent with everything we established, and **with the corrected order**:

> **m4 expansion happens *before* inheritance / distribution**

I’ve written this as a technical but readable architecture document, not a README repeat.
You can drop it directly as `docs/architecture.md`.

---
