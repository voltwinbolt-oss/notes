#!/usr/bin/env bash

file="$1"
indent=0
INDENT_SPACES=2

print_line() {
    local level="$1"
    local text="$2"
    printf "%*s%s\n" $((level * INDENT_SPACES)) "" "$text"
}

process_block_with_arrows() {
    local start_indent="$1"
    local first_line="$2"

    block=()
    block+=("$first_line")

    local max_key=0

    # Extract key length from first line
    if [[ "$first_line" =~ => ]]; then
        key="${first_line%%=>*}"
        key="${key%"${key##*[![:space:]]}"}"
        (( ${#key} > max_key )) && max_key=${#key}
    fi

    # Read additional lines until block ends (} or line without =>)
    while IFS= read -r next || [[ -n "$next" ]]; do
        stripped="$(echo "$next" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
        [[ -z "$stripped" ]] && break

        block+=("$stripped")

        if [[ "$stripped" =~ => ]]; then
            key="${stripped%%=>*}"
            key="${key%"${key##*[![:space:]]}"}"
            (( ${#key} > max_key )) && max_key=${#key}
        fi

        [[ "$stripped" =~ \}$ ]] && break
    done

    # Print block with aligned arrows and correct indentation
    for line in "${block[@]}"; do
        # Closing brace → print at parent indent
        if [[ "$line" =~ ^\} ]]; then
            print_line "$start_indent" "}"
            return 0
        fi

        if [[ "$line" =~ => ]]; then
            key="${line%%=>*}"
            key="${key%"${key##*[![:space:]]}"}"
            val="${line#*=>}"
            printf "%*s%-*s =>%s\n" \
                $((start_indent * INDENT_SPACES)) "" \
                $max_key "$key" \
                "$val"
        else
            print_line "$start_indent" "$line"
        fi
    done
}

# MAIN
while IFS= read -r line || [[ -n "$line" ]]; do
    stripped="$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

    [[ -z "$stripped" ]] && echo "" && continue

    # Decrease indent before printing closing brace
    if [[ "$stripped" =~ ^\} ]]; then
        ((indent--))
        print_line "$indent" "}"
        continue
    fi

    # Arrow-containing line → send to aligned block processor
    if [[ "$stripped" =~ => ]]; then
        process_block_with_arrows "$indent" "$stripped"
        continue
    fi

    # Print normal line
    print_line "$indent" "$stripped"

    # Increase indent after opening brace
    if [[ "$stripped" =~ \{$ ]]; then
        ((indent++))
    fi
done < "$file"
