# parsarg.jq — DFA argument parser in jq

## Concept

Instead of bash's extglob patterns and imperative state tracking, use jq's `reduce` to process arguments and output bash-evalable arrays.

```bash
eval "$(jq -f parsarg.jq --args --opt val --flag file.txt)"
# Sets: opts, args, cont in current shell
```

## Implementation

```jq
# State machine for argument parsing
# States: START, OPT, ARGS, DONE

def parse:
  # Initial state
  {
    state: "START",
    opts: {},
    args: [],
    cont: [],
    current_opt: null
  }
  | reduce $ARGS.positional[] as $arg (.;
    
    # ARGS state: everything goes to cont
    if .state == "ARGS" then
      .cont += [$arg]
    
    # ++ marker: stop and put rest in cont
    elif $arg == "++" then
      .state = "ARGS"
    
    # -- marker: stop and put rest in cont
    elif $arg == "--" then
      .state = "ARGS"
    
    # --key=value assignment
    elif $arg | test("^--[^=]+=") then
      .opts[$arg | split("=")[0] | ltrimstr("--")] = ($arg | split("="; 1)[1] // "")
    
    # -k=value assignment (not -<digit>)
    elif $arg | test("^-[^0-9=]+=") then
      .opts[$arg | split("=")[0] | ltrimstr("-")] = ($arg | split("="; 1)[1] // "")
    
    # --key without value
    elif $arg | test("^--[^-]") then
      .opts[$arg | ltrimstr("--")] = ((.opts[$arg | ltrimstr("--")] // 0) + 1 | tostring)
    
    # -k (short option, possibly multiple like -xyz)
    elif $arg | test("^-[^0-9-]") then
      # Expand -xyz into -x -y -z, increment each
      reduce (($arg | ltrimstr("-") | split("")) | .[]) as $c (.;
        .opts[$c] = ((.opts[$c] // 0) + 1 | tostring)
      )
    
    # In OPT state: this is a value for current_opt
    elif .state == "OPT" then
      .opts[.current_opt] += " " + $arg
    
    # Otherwise: positional argument
    else
      .args += [$arg]
    end
  )
  # Clear current_opt before output
  | del(.current_opt)
;

# Output bash declarations
def to_bash:
  "local -A opts=( \(.opts | to_entries | map("[\(.key)]=\(.value | @sh)") | join(" ")) );",
  "local -a args=( \(.args | map(@sh) | join(" ")) );",
  "local -a cont=( \(.cont | map(@sh) | join(" ")) );"
;

parse | to_bash
```

## Problems with This First Draft

1. **OPT state never exits** — once in OPT, every subsequent arg is absorbed as value (same bug as bash version)

2. **No lookahead** — can't tell if next arg is value or flag without looking ahead

3. **`-x val --flag`** — `--flag` gets absorbed as value

## Better Approach: Two-Pass

Pass 1: Classify each arg (FLAG, ASSIGN, MARKER, VALUE)
Pass 2: Process classifications with state

```jq
def classify:
  if . == "++" or . == "--" then {type: "MARKER", value: .}
  elif test("^--[^=]+=") then {type: "ASSIGN", key: (ltrimstr("--") | split("=")[0]), value: (split("="; 1)[1] // "")}
  elif test("^-[^0-9=]+=") then {type: "ASSIGN", key: (ltrimstr("-") | split("=")[0]), value: (split("="; 1)[1] // "")}
  elif test("^--[^-]") then {type: "FLAG", key: ltrimstr("--")}
  elif test("^-[^0-9-]") then {type: "SHORT", keys: (ltrimstr("-") | split(""))}
  elif test("^-[0-9]") then {type: "VALUE", value: .}  # -123 is a value
  elif test("^-") then {type: "VALUE", value: .}       # single - is a value
  else {type: "VALUE", value: .}
  end;

def parse:
  # Classify all args first
  [$ARGS.positional[] | classify]
  | {
      state: "START",
      opts: {},
      args: [],
      cont: [],
      current_opt: null,
      classified: .
    }
  | reduce .classified[] as $item (.;
    
    if .state == "DONE" then
      .cont += [$item.value // $item]
    
    elif $item.type == "MARKER" then
      .state = "DONE"
    
    elif $item.type == "ASSIGN" then
      .opts[$item.key] = $item.value
      | .state = "START"
      | .current_opt = null
    
    elif $item.type == "FLAG" then
      .opts[$item.key] = "1"
      | .state = "START"  
      | .current_opt = null
    
    elif $item.type == "SHORT" then
      reduce $item.keys[] as $k (.opts; .[$k] = ((.[$k] // 0) + 1 | tostring))
      | .opts = .
      | .state = "START"
      | .current_opt = null
    
    elif .state == "OPT" and $item.type == "VALUE" then
      .opts[.current_opt] += " " + $item.value
    
    elif .state == "OPT" and $item.type != "VALUE" then
      # Exit OPT state, re-process this item
      .state = "START"
      | .current_opt = null
      # Oops, can't easily re-process in reduce...
    
    elif $item.type == "VALUE" then
      .args += [$item.value]
    
    else
      .
    end
  )
;
```

## The Real Problem: OPT State Semantics

The fundamental issue (same as bash): what *should* `--opt val1 val2` do?

Options:
1. **Single value:** `opts[opt] = "val1"`, `args = ["val2"]`
2. **Accumulate:** `opts[opt] = "val1 val2"`
3. **Require `--`:** `--opt val --` terminates value collection

The bash version does #2 but absorbs flags too. That's the bug.

## Cleanest Design: Explicit Termination

```jq
# Rules:
# 1. --opt val → opts[opt] = val, next arg starts fresh
# 2. --opt val1 val2 → error or opts[opt] = "val1", args += val2
# 3. Use --opt=val for values with spaces
# 4. Use -- to separate opts from args

def parse_explicit:
  [$ARGS.positional[] | classify]
  | {opts: {}, args: [], cont: [], state: "START", current_opt: null}
  | reduce .[] as $item (.;
    
    if .state == "DONE" then
      .cont += [$item.value // $item]
    
    elif $item.type == "MARKER" then
      if .current_opt then .opts[.current_opt] = (.opts[.current_opt] // "1") end
      | .state = "DONE"
      | .current_opt = null
    
    elif $item.type == "ASSIGN" then
      if .current_opt then .opts[.current_opt] = (.opts[.current_opt] // "1") end
      | .opts[$item.key] = $item.value
      | .current_opt = null
    
    elif $item.type == "FLAG" then
      if .current_opt then .opts[.current_opt] = (.opts[.current_opt] // "1") end
      | .opts[$item.key] = "1"
      | .current_opt = $item.key  # Might get a value next
    
    elif $item.type == "SHORT" then
      if .current_opt then .opts[.current_opt] = (.opts[.current_opt] // "1") end
      | reduce $item.keys[] as $k (.opts; .[$k] = "1")
      | .opts = .
      | .current_opt = ($item.keys[-1])  # Last short opt might get value
    
    elif $item.type == "VALUE" and .current_opt and .opts[.current_opt] == "1" then
      # This value is for the current opt
      .opts[.current_opt] = $item.value
      | .current_opt = null
    
    elif $item.type == "VALUE" then
      .args += [$item.value]
    
    else .
    end
  )
  | del(.state, .current_opt)
;
```

This is cleaner but still has edge cases.

## Verdict

Yes, jq version is more maintainable. Benefits:

| Aspect | Bash | jq |
|--------|------|-----|
| State machine | Imperative, mutable | `reduce`, immutable |
| Pattern matching | extglob, fragile | regex, clear |
| Debugging | `set -x`, messy | `-n` flag, inspect state |
| Testing | Run bash functions | Unit test jq functions |
| Output | Direct | Requires `eval` |

The `eval` overhead is negligible for argument parsing (once per script invocation).

Want me to develop a complete, tested version?
