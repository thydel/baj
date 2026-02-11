# baj-lib.yml Bug Report

Analysis of `/home/z/my-project/baj/baj-lib.yml` for potential bugs and issues.

---

## 1. Duplicate Entry in na List (Line 13)

**Severity:** Low (cosmetic)

```yaml
- id: [ txt1, nss1, fn1, listid1, fn1, def1, ids1, forget1, lib1, exp1, warn, optal ]
```

`fn1` appears twice in the list. This is likely a copy-paste error. No functional impact since it's just a list, but suggests the code hasn't been carefully reviewed.

---

## 2. `nsp` Doesn't Correctly Test Namespace Existence (Line 99)

**Severity:** High

```yaml
- { id: nsp, sh: 'compgen -c ns:${1:?} > /dev/null' }
```

**Problem:** `compgen -c` returns exit code 0 even when no matches are found. It outputs nothing, but still exits successfully.

**Impact:** Any code relying on `nsp` to detect namespace existence will get false positives.

**Fix:**
```bash
[[ $(compgen -c ns:${1:?}) ]]
```

**Affected functions:** `aliases1`, `forget1`, `lib1` — all use `nsp` as a condition.

---

## 3. `map` Doesn't Handle Empty Lines (Line 72)

**Severity:** Medium

```yaml
- { id: map, sh: 'while read; do "${@:-echo}" "$REPLY"; done' }
```

**Problem:** `read` stops at the first empty line with default IFS. Also doesn't handle trailing newlines correctly (last line without newline is lost).

**Fix:**
```bash
while IFS= read -r || [[ -n $REPLY ]]; do "${@:-echo}" "$REPLY"; done
```

---

## 4. `fail` Message Formatting Issue (Line 68)

**Severity:** Low

```yaml
- { id: fail, sh: 'unset -v fail; : "${fail:?${FUNCNAME[1]} $@}"' }
```

**Problem:** `$@` expands to separate words. If `fail` is called with multiple arguments like `fail something went wrong`, the error message becomes unpredictable depending on how the shell joins the arguments.

**Fix:** Use `"$*"` instead of `$@`:
```bash
unset -v fail; : "${fail:?${FUNCNAME[1]} $*}"
```

---

## 5. `def1` Confusing Logic Chain (Line 95)

**Severity:** Medium

```yaml
- { id: def1, sh: '[[ -v BASH_ALIASES[${1:?}] ]] || fail $1 not an alias && declare -f ${BASH_ALIASES[$1]}' }
```

**Problem:** The `||` and `&&` chain is evaluated left-to-right:
```
([[ -v ... ]] || fail ...) && declare -f ...
```

This works because `fail` exits via parameter expansion error. But if `fail` somehow doesn't exit (e.g., in a subshell with error trapping disabled), the logic breaks and `declare -f` runs with an empty `${BASH_ALIASES[$1]}`.

**Additional issue:** `fail $1 not an alias` has unquoted arguments — should be `fail "$1 not an alias"`.

**Fix:** Rewrite with clearer logic:
```bash
[[ -v BASH_ALIASES[${1:?}] ]] || { fail "$1 not an alias"; return 1; }
declare -f "${BASH_ALIASES[$1]}"
```

---

## 6. `ns` Unquoted Arguments to `fail` (Line 97)

**Severity:** Low

```yaml
- { id: ns, sh: '(($# == 0)) || fail too many args; compgen -c ns: | cut -d: -f2' }
```

**Problem:** `fail too many args` — three separate arguments, no quoting. Works by accident because `fail` uses `$@` which joins them, but fragile.

**Fix:**
```bash
(($# == 0)) || fail "too many args"; compgen -c ns: | cut -d: -f2
```

---

## ~~7. `md2js` Array Subscript on Scalar (Line 56)~~ — NOT A BUG

```yaml
- id: md2js
  jq:
    header: |-
      ...
    md2js: |-
      ...
  sh: |-
    pandoc -t json | jq "${jq[md2js]}" | jq "${jq[header]}" -n --arg ns ${1:?}
```

**Initial concern:** The `jq` variable is an object — would bash handle `${jq[md2js]}`?

**Resolution:** The `emit` function in `baj-core.md` handles this correctly:

```jq
def sh_var:
  (.value | type) as $t
  | if $t == "array" then sh_array_var
    elif $t == "object" then sh_map_var
    else "local \(.key)=\(.value | @sh)" end;
```

Object values become `local -A key=(...)` associative arrays. So `${jq[md2js]}` works as intended. **No bug.**

---

## 8. `with-lib` Unquoted `$f` (Line 130)

**Severity:** Low

```yaml
(($#)) && { f=${BASH_ALIASES[$1]:-$1}; shift; echo $f "${@@Q}"; }
```

**Problem:** `$f` is unquoted. Function names shouldn't have spaces, but defensive quoting is better.

**Fix:**
```bash
echo "$f" "${@@Q}"
```

---

## 9. `ids1` Unnecessary `eval` (Line 88)

**Severity:** Low (code smell)

```yaml
- { id: ids1, jq: '.[].id', sh: 'eval ${1:?} src | SELF(-r)' }
```

**Problem:** `eval` is used to call a function by name, but bash can do this directly. `eval` adds unnecessary risk if `$1` contains special characters.

**Fix:**
```bash
${1:?}:src | SELF(-r)
```

(Or keep eval if there's a specific reason, but document why.)

---

## 10. `opts` Sets `cont` But Never Uses It (Lines 38-40)

**Severity:** Low (dead code)

```yaml
done; cont=("$@")
tt: |
  local -A opts; local args cont; opts "$@"
```

**Problem:** `cont` is set in `opts` but the value is never returned or accessible to the caller. The `tt` template suggests it should be available, but bash functions can't return arrays.

**Note:** This might be intentional for caller pattern matching, but worth clarifying in comments.

---

## 11. `aliases1` Depends on Broken `nsp` (Line 106)

**Severity:** High (cascading from bug #2)

```yaml
nsp ${1:?} || fail not a ns; self -nr ...
```

Since `nsp` always returns 0, `fail not a ns` never runs, and the function proceeds even for invalid namespaces. The jq filter `test("\($ns):")` will then fail to match anything, returning empty output silently.

---

## 12. Potential Issue with m4 Macro Expansion in OPTS (Line 66)

**Severity:** Unclear (needs testing)

```yaml
OPTS: |-
  local -A opts; local args cont; opts "$«@»"
```

The `«@»` uses French guillemets as m4 quotes. The intent is to pass literal `$@` through m4. However, the interaction between m4's quoting rules and subsequent bash expansion needs verification. If `@` somehow gets interpreted as an m4 macro (unlikely but possible with certain configurations), this could break.

---

## Summary

| # | Issue | Severity | Function |
|---|-------|----------|----------|
| 1 | Duplicate `fn1` in list | Low | n/a |
| 2 | `nsp` returns 0 even with no match | **High** | `nsp` |
| 3 | `map` stops at empty lines | Medium | `map` |
| 4 | `fail` uses `$@` instead of `$*` | Low | `fail` |
| 5 | `def1` confusing `||`/`&&` chain | Medium | `def1` |
| 6 | `ns` unquoted args to `fail` | Low | `ns` |
| ~~7~~ | ~~Array subscript on scalar~~ | ~~Not a bug~~ | `md2js` |
| 8 | Unquoted `$f` in `with-lib` | Low | `with-lib` |
| 9 | Unnecessary `eval` in `ids1` | Low | `ids1` |
| 10 | Dead code: `cont` never used | Low | `opts` |
| 11 | Cascading from bug #2 | High | `aliases1` |
| 12 | m4 quote interaction | Unclear | m4 macros |

---

## Recommended Actions

1. **Immediate:** Fix `nsp` — this breaks namespace detection throughout.
2. **Cleanup:** Remove duplicate `fn1`, add proper quoting, simplify `def1` logic.
3. **Investigate:** Test `map` with empty lines and edge cases.
