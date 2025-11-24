#!/usr/bin/env -S jq -f

# Helper: Extract plain text from Header inlines
def txt: .c[2] | map(.c // " ") | join("");

.blocks
| reduce .[] as $b (
    {list: [], curr: null};

    # 1. Handle Headers
    if $b.t == "Header" then
      ($b | txt) as $h
      | (if .curr then .list += [.curr] else . end) # Flush current
      | if ($h | startswith("id ")) then
          .curr = {id: ($h | sub("^id\\s+"; ""))}
        else
          .curr = null
        end

    # 2. Handle CodeBlocks
    elif $b.t == "CodeBlock" and .curr then
      .curr[($b.c[0][1][0] // "txt")] = $b.c[1]

    # 3. Ignore others
    else . end
  )
# Final flush and output list
| (if .curr then .list += [.curr] else . end)
| .list
