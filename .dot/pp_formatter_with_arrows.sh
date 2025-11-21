#!/usr/bin/env bash
# pp_formatter_align.sh
# Usage: ./pp_formatter_align.sh input.pp > output.pp

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <file.pp>"
  exit 1
fi

file="$1"
indent=0
spaces="  "  # 2 spaces per indent

# Read file line by line
while IFS= read -r line; do
    clean_line="$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

    # Skip empty lines
    if [[ -z "$clean_line" ]]; then
        echo ""
        continue
    fi

    # Decrease indent for closing brace
    if [[ "$clean_line" =~ ^\} ]]; then
        ((indent--))
    fi

    # If line contains arrows, collect all lines in the current block for alignment
    if [[ "$clean_line" =~ => ]]; then
        block_lines=()
        max_key_len=0

        # Start reading the block
        block_lines+=("$clean_line")
        key="${clean_line%%=>*}"
        key_len=${#key}
        (( key_len > max_key_len )) && max_key_len=$key_len

        # Read following lines until block ends (closing brace or empty)
        while IFS= read -r next_line; do
            next_clean="$(echo "$next_line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
            [[ -z "$next_clean" ]] && break
            block_lines+=("$next_clean")
            if [[ "$next_clean" =~ => ]]; then
                next_key="${next_clean%%=>*}"
                next_key_len=${#next_key}
                (( next_key_len > max_key_len )) && max_key_len=$next_key_len
            fi
            [[ "$next_clean" =~ ^\} ]] && break
        done

        # Print aligned block
        for l in "${block_lines[@]}"; do
            if [[ "$l" =~ => ]]; then
                key="${l%%=>*}"
                value="${l#*=>}"
                printf "%*s%-*s =>%s\n" $((indent*2)) "" $max_key_len "$key" "$value"
            else
                printf "%*s%s\n" $((indent*2)) "" "$l"
            fi
        done
        continue
    fi

    # Print normal line
    printf "%*s%s\n" $((indent*2)) "" "$clean_line"

    # Increase indent if line ends with {
    [[ "$clean_line" =~ \{$ ]] && ((indent++))
done < "$file"
