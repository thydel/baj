#!/usr/bin/env -S jq -f

# Helper: Extract plain text from Pandoc Header inlines.
# Note: Pandoc 'Space' objects have null .c, so we replace them with " ".
def txt: .c[2] | map(.c // " ") | join("");

def md2yml:
  .blocks | reduce .[] as $b ([];
    if $b.t == "Header" then ($b | txt) as $h |
      if $h | startswith("id ") then . + [{id: $h[3:]}] else . + [null] end
    elif $b.t == "CodeBlock" and .[-1] then
      .[-1][$b.c[0][1][0] // "txt"] = $b.c[1]
    end) | map(values);
    
def md2yml_with_comments:
  .blocks | reduce .[] as $b (
    # Initialize with an empty list.
    # We treat this list as a stack where .[-1] is the "active" object.
    [];
  
    # 1. State Change: Headers
    if $b.t == "Header" then
      ($b | txt) as $h |
      # If it marks an ID, append a new object to the list (becoming the new .[-1]).
      if $h | startswith("id ") then
        . + [{id: $h[3:]}]
      # If it's a different header, append null.
      # This effectively "closes" the previous object and prevents attaching code to the wrong ID.
      else
        . + [null]
      end
  
    # 2. Data Collection: CodeBlocks
    # Check if the block is code AND if we have an active object (.[-1] is truthy).
    elif $b.t == "CodeBlock" and .[-1] then
      # Update the last object in the list.
      # Key: First class in the class list (e.g., "bash"), default to "txt".
      # Value: The code content string.
      .[-1][$b.c[0][1][0] // "txt"] = $b.c[1]
    
    # 3. Fallback
    # Implicit 'else .' keeps the accumulator unchanged for paragraphs/other blocks.
    end
  )
  # Final Cleanup: Remove the 'null' separators we used to break context.
  | map(select(.));

md2yml
