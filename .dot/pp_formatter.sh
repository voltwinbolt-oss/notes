#!/usr/bin/env bash
# save as pp_formatter.sh
# Usage: ./pp_formatter.sh input.pp > output.pp

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <file.pp>"
  exit 1
fi

file="$1"

indent=0
spaces="  "  # 2 spaces per level

while IFS= read -r line; do
    # Strip leading/trailing whitespace
    clean_line="$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

    # Skip empty lines
    if [[ -z "$clean_line" ]]; then
        echo ""
        continue
    fi

    # Decrease indent if line starts with a closing brace
    if [[ "$clean_line" =~ ^\} ]]; then
        ((indent--))
    fi

    # Print line with current indentation
    printf "%*s%s\n" $((indent*2)) "" "$clean_line"

    # Increase indent if line ends with an opening brace
    if [[ "$clean_line" =~ \{$ ]]; then
        ((indent++))
    fi
done < "$file"

