#!/usr/bin/env bash

file="$1"
INDENT=2

# Stack to track indentation levels
declare -a stack
stack=(0)

indent() { printf "%*s" "$1" ""; }

# Detect lines that open blocks (class, define, resource, if, case, else)
opens_block() {
    [[ "$1" =~ \{$ ]]
}

# Detect closing brace
closes_block() {
    [[ "$1" =~ ^\} ]]
}

# Align arrows inside a block of params
align_arrows_block() {
    local current_indent="$1"
    local line="$2"

    local block=()
    block+=("$line")
    local max_key=0

    # Measure first key
    if [[ "$line" =~ => ]]; then
        key="${line%%=>*}"
        key="$(echo "$key" | sed 's/[[:space:]]*$//')"
        (( ${#key} > max_key )) && max_key=${#key}
    fi

    # Continue reading until block ends or no more =>
    while IFS= read -r next || [[ -n "$next" ]]; do
        stripped="$(echo "$next" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

        # Stop if blank or not a param
        [[ -z "$stripped" ]] && break

        block+=("$stripped")

        if [[ "$stripped" =~ => ]]; then
            key="${stripped%%=>*}"
            key="$(echo "$key" | sed 's/[[:space:]]*$//')"
            (( ${#key} > max_key )) && max_key=${#key}
        fi

        # Stop when encountering }
        [[ "$stripped" =~ \}$ ]] && break
    done

    # Print aligned block
    for l in "${block[@]}"; do
        if [[ "$l" =~ ^\} ]]; then
            indent "${stack[-1]}" ; echo "}"
            # Dedent stack
            unset 'stack[-1]'
            return 0
        elif [[ "$l" =~ => ]]; then
            key="${l%%=>*}"
            key="$(echo "$key" | sed 's/[[:space:]]*$//')"
            val="${l#*=>}"

            indent "$current_indent"
            printf "%-*s =>%s\n" $max_key "$key" "$val"
        else
            indent "$current_indent"
            echo "$l"
        fi
    done
}

### MAIN LOOP ###
while IFS= read -r raw || [[ -n "$raw" ]]; do
    line="$(echo "$raw" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

    # Skip empty lines
    [[ -z "$line" ]] && echo "" && continue

    # Closing brace → dedent *before printing*
    if closes_block "$line" ; then
        unset 'stack[-1]'
        indent "${stack[-1]}"
        echo "}"
        continue
    fi

    # Arrow block (params)
    if [[ "$line" =~ => ]]; then
        align_arrows_block "${stack[-1]}" "$line"
        continue
    fi

    # Print normal line
    indent "${stack[-1]}"
    echo "$line"

    # Block opening → push a deeper indent level
    if opens_block "$line"; then
        stack+=($(( stack[-1] + INDENT )))
    fi

done < "$file"
