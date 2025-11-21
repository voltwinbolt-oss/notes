#!/usr/bin/env bash

file="$1"
INDENT=2

# Stack of indentation contexts
# Each entry: type:indent, type = "brace" or "paren"
stack=("brace:0")

indent() {
    printf "%*s" "$1" ""
}

# Detect block opening/closing
opens_brace_block() { [[ "$1" =~ \{$ ]]; }
closes_brace_block() { [[ "$1" =~ ^\} ]]; }

opens_paren_block() { [[ "$1" =~ \($ ]]; }
closes_paren_block() { [[ "$1" =~ ^\) ]]; }

# Align arrows in resource param blocks
align_arrows_block() {
    local indent_level="$1"
    local first_line="$2"
    local block=("$first_line")
    local max_key=0

    strip_trail() { echo "$1" | sed 's/[[:space:]]*$//'; }

    # Measure first line key
    if [[ "$first_line" =~ "=>" ]]; then
        key="${first_line%%=>*}"
        key="$(strip_trail "$key")"
        (( ${#key} > max_key )) && max_key=${#key}
    fi

    # Read additional lines until closing brace or blank line
    while IFS= read -r next || [[ -n "$next" ]]; do
        local stripped="$(echo "$next" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
        [[ -z "$stripped" ]] && break

        block+=("$stripped")

        if [[ "$stripped" =~ "=>" ]]; then
            key="${stripped%%=>*}"
            key="$(strip_trail "$key")"
            (( ${#key} > max_key )) && max_key=${#key}
        fi

        [[ "$stripped" =~ \}$ ]] && break
    done

    # Print aligned block
    for line in "${block[@]}"; do
        if [[ "$line" =~ ^\} ]]; then
            # pop brace from stack
            last=$(( ${#stack[@]} - 1 ))
            unset "stack[$last]"

            # print closing brace at new top indent
            last=$(( ${#stack[@]} - 1 ))
            indent "${stack[$last]#*:}"
            echo "}"
            return 0
        fi

        if [[ "$line" =~ "=>" ]]; then
            key="${line%%=>*}"
            key="$(strip_trail "$key")"
            val="${line#*=>}"

            indent "$indent_level"
            printf "%-*s =>%s\n" "$max_key" "$key" "$val"
        else
            indent "$indent_level"
            echo "$line"
        fi
    done
}

### MAIN LOOP ###
while IFS= read -r raw || [[ -n "$raw" ]]; do
    line="$(echo "$raw" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

    [[ -z "$line" ]] && echo "" && continue

    # Handle closing braces
    if closes_brace_block "$line"; then
        last=$(( ${#stack[@]} - 1 ))
        unset "stack[$last]"
        last=$(( ${#stack[@]} - 1 ))
        indent "${stack[$last]#*:}"
        echo "}"
        continue
    fi

    # Handle closing parentheses
    if closes_paren_block "$line"; then
        last=$(( ${#stack[@]} - 1 ))
        # Only pop if top is paren
        [[ "${stack[$last]%%:*}" == "paren" ]] && unset "stack[$last]"
        last=$(( ${#stack[@]} - 1 ))
        indent "${stack[$last]#*:}"
        echo ")"
        continue
    fi

    # Arrow param block
    if [[ "$line" =~ "=>" ]]; then
        last=$(( ${#stack[@]} - 1 ))
        current_indent="${stack[$last]#*:}"
        align_arrows_block "$current_indent" "$line"
        continue
    fi

    # Normal line
    last=$(( ${#stack[@]} - 1 ))
    indent "${stack[$last]#*:}"
    echo "$line"

    # Handle block openings
    if opens_brace_block "$line"; then
        last=$(( ${#stack[@]} - 1 ))
        new_indent=$(( ${stack[$last]#*:} + INDENT ))
        stack+=("brace:$new_indent")
    elif opens_paren_block "$line"; then
        last=$(( ${#stack[@]} - 1 ))
        new_indent=$(( ${stack[$last]#*:} + INDENT ))
        stack+=("paren:$new_indent")
    fi
done < "$file"
