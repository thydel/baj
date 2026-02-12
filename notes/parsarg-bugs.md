# parsarg.md Bug Report

Analysis of `/home/z/my-project/baj/parsarg.md` — a DFA-style argument parser for bash.

---

## 1. Typo in Documentation (Line 24)

**Severity:** Trivial

```markdown
- Based on dymamic scopying of `bash`
```

**Fix:** "dymamic scopying" → "dynamic scoping"

---

## 2. OPT State Absorbs Subsequent Flags (Lines 78-80)

**Severity:** High (surprising behavior)

```bash
elif [[ "$ctx" == START^$LONG^VAL ]]; then    do=LONG-VAL  state=OPT;
...
elif [[ "$ctx" == OPT^$ANY^VAL ]];    then    do=OPT-VAL;
elif [[ "$ctx" == OPT^$ANY^END ]];    then    do=OPT-VAL   state=START;
```

**Problem:** After `--opt value`, state is `OPT`. The next argument matching `$VAL` is absorbed via `OPT-VAL`, which *appends* to the previous option:

```bash
OPT-VAL) opts["$opt"]+=" $1"; shift;;
```

**Example:**
```bash
parsarg --opt val --flag
# Result: opts["opt"] = "val --flag"
# Expected: opts["opt"] = "val", opts["flag"] = 1
```

`--flag` is consumed as a value to `--opt`, not recognized as a flag. The state machine only exits `OPT` when it sees `$END` (something starting with `-` but not a number).

**Impact:** Any flag-like value (`-x`, `--something`) passed after a `--opt value` pair gets silently absorbed.

**Fix:** The `OPT` state should only accept values that *don't* look like flags:

```bash
elif [[ "$ctx" == OPT^$VAL^$ANY ]]; then       do=OPT-VAL;
elif [[ "$ctx" == OPT^$VAL^END ]]; then        do=OPT-VAL   state=START;
```

But this requires rethinking what `$VAL` means — currently it includes `-[0-9]*` and `-[!-]*` would be `$END`. The logic is tangled.

---

## 3. ERROR Action Continues Instead of Failing (Line 104)

**Severity:** Medium

```bash
ERROR|*) { echo $# "$@"; declare -p do state next; } | fmt -999; shift;
```

**Problem:** On error, the parser prints debug info, shifts one argument, and *continues parsing*. This can cause:

1. Cascading errors from a single malformed argument
2. Incorrect results if the rest of input is valid
3. No indication to the caller that parsing failed

**Example:**
```bash
parsarg --opt=val=with=equals file.txt
# If "=" handling has an edge case, parser continues, may partially succeed
```

**Fix:** Return non-zero on error:

```bash
ERROR|*) { echo "parsarg error: $# $@" >&2; declare -p do state next >&2; return 1; }
```

---

## 4. Empty Key Accepted for Assignment (Line 53, 97-98)

**Severity:** Low

```bash
local ASSIGN='@(--*=*|-[!0-9]*=*)'
...
opt="${opt##+(-)}"  # Strip dashes
```

**Problem:** Input like `--=value` or `-=value` matches `ASSIGN`. After stripping dashes, `opt` is empty string:

```bash
parsarg --=value
# Result: opts[""] = "value"
```

Empty-string keys are valid in bash associative arrays, but probably not intended.

**Fix:** Reject empty keys:

```bash
ASSIGN)
    opt="${1%%=*}"; val="${1#*=}"; opt="${opt##+(-)}"
    [[ -z "$opt" ]] && { echo "empty option key" >&2; return 1; }
    opts["$opt"]="$val"; shift;;
```

---

## 5. Arithmetic on Unset Array Element (Line 101)

**Severity:** Trivial (works, but unclear)

```bash
LONG-END) opt="${1:2}"; opts["$opt"]=$((opts["$opt"] + 1)); shift;;
```

**Problem:** `$((opts["$opt"] + 1))` works because bash treats unset variables as 0 in arithmetic context. But it's implicit behavior.

**Fix:** Be explicit:

```bash
opts["$opt"]=$((${opts["$opt"]:-0} + 1))
```

---

## 6. Missing Test Coverage for OPT State Transitions

**Severity:** Medium (testing gap)

The test suite in `gen-tests` doesn't cover:

| Case | Input | Expected | Tests Current Behavior? |
|------|-------|----------|------------------------|
| Flag after opt-val | `--opt val --flag` | `opts[opt]=val, opts[flag]=1` | No |
| Number after opt-val | `--opt val -123` | `opts[opt]="val -123"` or error? | No |
| Multiple values | `--opt val1 val2` | `opts[opt]="val1 val2"` | No |
| Value with equals | `--opt=val=equals` | `opts[opt]="val=equals"` | No |

**Impact:** Bug #2 likely exists undetected because no test exercises the `OPT` → `OPT` transition with a flag-like value.

**Fix:** Add tests:

```yaml
- tags: [ opt, val, flag ]
  test: [ --opt, val, --flag ]
  opts: [ opt, val, flag, 1 ]
- tags: [ opt, eq, embedded ]
  test: [ --opt=val=equals ]
  opts: [ opt, "val=equals" ]
```

---

## 7. `-x value` Followed by Another Flag

**Severity:** High (same root as #2)

Short options with values have the same problem:

```bash
parsarg -x val --flag
# What happens?
# 1. -x is SHORT → expanded to --x
# 2. --x with next=val → LONG-VAL, state=OPT
# 3. --flag with next=? → OPT-VAL (if VAL) or OPT-VAL (if END)
```

The state machine treats `-x val --flag` as:
- `--x` gets value `val`
- `--flag` is... absorbed or handled?

Depends on what `--flag` matches in the lookahead. If `$VAL`, it's absorbed. If `$END`, state resets.

**This is a fundamental ambiguity in the DFA design.**

---

## 8. Inconsistent `-` Handling (Lines 45, 29)

**Severity:** Low (unclear intent)

```bash
local VAL='@(-|[!-]*|-[0-9]*)'  # Line 45
...
# -[0-9]*)                        # Line 28 comment
```

Single `-` is classified as `$VAL` (a value). So:

```bash
parsarg -x -
# -x → SHORT → --x
# - → VAL
# Result: opts["x"] = "-" ?
```

Is `-` as a value intentional? Commonly, `-` means stdin. But it's not documented.

---

## Summary

| # | Issue | Severity |
|---|-------|----------|
| 1 | Typo "dymamic scopying" | Trivial |
| 2 | OPT state absorbs flags | **High** |
| 3 | ERROR continues instead of failing | Medium |
| 4 | Empty key accepted | Low |
| 5 | Arithmetic on unset element | Trivial |
| 6 | Missing test coverage | Medium |
| 7 | Short option value ambiguity | **High** |
| 8 | Undocumented `-` handling | Low |

---

## Recommended Actions

1. **Critical:** Redesign `OPT` state transitions. Either:
   - Only accept non-flag values in `OPT` state
   - Add explicit termination marker (e.g., `;` or require `--` before flags)

2. **Add tests** for edge cases before fixing — current behavior might be intentional.

3. **Fail fast:** `ERROR` should `return 1`, not continue.

4. **Validate keys:** Reject empty option keys.
