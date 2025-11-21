#!/usr/bin/env bash

file="$1"
INDENT=2

# Stack of indentation values
stack=(0)

indent() {
    printf "%*s" "$1" ""
}

opens_block() {
    [[ "$1" =~ \{$ ]]
}

closes_block() {
    [[ "$1" =~ ^\} ]]
}

align_arrows_block() {
    local indent_level="$1"
    local first_line="$2"

    local block=("$first_line")
    local max_key=0

    # helper function to strip trailing spaces
    strip_trail() { echo "$1" | sed 's/[[:space:]]*$//'; }

    # measure first key
    if [[ "$first_line" =~ "=>" ]]; then
        key="${first_line%%=>*}"
        key="$(strip_trail "$key")"
        (( ${#key} > max_key )) && max_key=${#key}
    fi

    # read additional param lines
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

    # print the aligned block
    for line in "${block[@]}"; do
        # if closing brace
        if [[ "$line" =~ ^\} ]]; then
            # pop stack level
            last=$(( ${#stack[@]} - 1 ))
            unset "stack[$last]"

            # print at new top indent
            last=$(( ${#stack[@]} - 1 ))
            indent "${stack[$last]}"
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

    # CASE 1 — closing brace
    if closes_block "$line" ; then
        last=$(( ${#stack[@]} - 1 ))
        unset "stack[$last]"

        last=$(( ${#stack[@]} - 1 ))
        indent "${stack[$last]}"
        echo "}"
        continue
    fi

    # CASE 2 — param block with =>
    if [[ "$line" =~ "=>" ]]; then
        last=$(( ${#stack[@]} - 1 ))
        current_indent="${stack[$last]}"
        align_arrows_block "$current_indent" "$line"
        continue
    fi

    # CASE 3 — normal line
    last=$(( ${#stack[@]} - 1 ))
    indent "${stack[$last]}"
    echo "$line"

    # CASE 4 — opening brace
    if opens_block "$line"; then
        last=$(( ${#stack[@]} - 1 ))
        new_indent=$(( stack[$last] + INDENT ))
        stack+=("$new_indent")
    fi

done < "$file"
