#!/usr/bin/env bash

file="$1"
INDENT=2

# Stack of indentation contexts; always at least one element
stack=("brace:0")

indent() { printf "%*s" "$1" ""; }

opens_brace_block() { [[ "$1" =~ \{$ ]]; }
closes_brace_block() { [[ "$1" =~ ^\} ]]; }

opens_paren_block() { [[ "$1" =~ \($ ]]; }
closes_paren_block() { [[ "$1" =~ ^\) ]]; }

align_arrows_block() {
    local indent_level="$1"
    local first_line="$2"
    local block=("$first_line")
    local max_key=0

    strip_trail() { echo "$1" | sed 's/[[:space:]]*$//'; }

    if [[ "$first_line" =~ "=>" ]]; then
        key="${first_line%%=>*}"
        key="$(strip_trail "$key")"
        (( ${#key} > max_key )) && max_key=${#key}
    fi

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

    for line in "${block[@]}"; do
        if [[ "$line" =~ ^\} ]]; then
            # Pop brace only if stack > 1
            last=$(( ${#stack[@]} - 1 ))
            [[ $last -gt 0 ]] && unset "stack[$last]"

            # print closing brace at current top indent
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

    # CASE: closing brace
    if closes_brace_block "$line"; then
        last=$(( ${#stack[@]} - 1 ))
        [[ $last -gt 0 ]] && unset "stack[$last]"
        last=$(( ${#stack[@]} - 1 ))
        indent "${stack[$last]#*:}"
        echo "}"
        continue
    fi

    # CASE: closing parenthesis
    if closes_paren_block "$line"; then
        last=$(( ${#stack[@]} - 1 ))
        [[ $last -gt 0 && "${stack[$last]%%:*}" == "paren" ]] && unset "stack[$last]"
        last=$(( ${#stack[@]} - 1 ))
        indent "${stack[$last]#*:}"
        echo ")"
        continue
    fi

    # CASE: arrow param
    if [[ "$line" =~ "=>" ]]; then
        last=$(( ${#stack[@]} - 1 ))
        current_indent="${stack[$last]#*:}"
        align_arrows_block "$current_indent" "$line"
        continue
    fi

    # CASE: normal line
    last=$(( ${#stack[@]} - 1 ))
    indent "${stack[$last]#*:}"
    echo "$line"

    # CASE: opening blocks
    last=$(( ${#stack[@]} - 1 ))
    current_indent="${stack[$last]#*:}"

    if opens_brace_block "$line"; then
        new_indent=$(( current_indent + INDENT ))
        stack+=("brace:$new_indent")
    elif opens_paren_block "$line"; then
        new_indent=$(( current_indent + INDENT ))
        stack+=("paren:$new_indent")
    fi
done < "$file"
