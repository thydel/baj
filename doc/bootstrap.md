# System Architecture & Bootstrapping

To provide advanced syntax and extended functionality, the system
relies on a macro processor (`baj:m4`). However, a fundamental
architectural constraint is that the macro processor cannot process
its own definition.

To resolve this circular dependency, the system is split into two
distinct layers: the **Core** (Raw) layer and the **Library**
(Enhanced) layer.

## The Core Layer (`baj:init`)

This is the bootstrap layer. It provides the essential machinery
required to start the system and load the macro processor.

  * **Entry Point:** `baj:init`
  * **Characteristics:**
      * **Raw Implementation:** This layer is strictly prohibited from
        using any `m4` macros in its source code.
      * **Functionality:** It contains the bare minimum logic needed
        to read files, interpret basic commands, and execute hooks.
  * **Relation to Main:** `baj:init` is effectively the system running
    in "raw mode"—it is what `baj:main` would be if no macros were
    ever applied.

## The Library Layer (`baj:main`)

This layer constitutes the standard library and the full-featured
runtime environment intended for general use.

  * **Entry Point:** `baj:main`
  * **Characteristics:**
      * **Macro-Enhanced:** The source code for this layer heavily
        utilizes `m4` macros for cleaner syntax, abstractions, and
        advanced features.
  * **Dependency:** It cannot run directly. It relies on the Core
    layer to process its raw source code into executable form.

## The Bootstrap Sequence

The system starts up in stages to transition from raw code to a macro-expanded runtime:

1.  **Stage 1 (Raw Boot):** The system loads `baj:init` (the
    Core). Because this file uses no macros, it loads directly.
2.  **Stage 2 (Macro Loader):** `baj:init` loads the raw definitions
    for `baj:m4`. At this point, the Core has the capability to expand
    macros.
3.  **Stage 3 (Expansion):** The Core reads the source code for the
    Library layer. It passes this source through the loaded `baj:m4`
    definitions, expanding all macros into final, executable code.
4.  **Stage 4 (Runtime Transfer):** The fully expanded code becomes
    resident in memory as `baj:main`. Execution control is transferred
    to `baj:main`, completing the bootstrap.
