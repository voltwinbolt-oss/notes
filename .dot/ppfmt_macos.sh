#!/usr/bin/env bash
# ppfmt - Minimal Puppet manifest formatter (non-hanging, macOS safe)

INDENT=2

# Stack of indent levels (numbers)
declare -a INDENT_STACK=(0)

# States
IN_CLASS_HEADER=0
EXPECTING_CLASS_BRACE=0
IN_ARROW_BLOCK=0

BUFFER_CLASS_HEADER=()
BUFFER_ARROW_BLOCK=()

# Utilities
indent() { printf "%*s" "$1" ""; }
strip() { echo "$1" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'; }

stack_depth() {
    echo "${INDENT_STACK[-1]}"
}
push_indent() {
    INDENT_STACK+=("$1")
}
pop_indent() {
    local len=${#INDENT_STACK[@]}
    if (( len > 1 )); then
        unset "INDENT_STACK[$((len-1))]"
    fi
}

# Checkers
is_class_define_start() { [[ "$1" =~ ^(class|define)[[:space:]]+[a-zA-Z0-9_:]+[[:space:]]*\( ]]; }
ends_class_header_paren() { [[ "$1" == *")" ]] && [[ "$1" != *"{"* ]]; }
ends_class_header_paren_and_brace() { [[ "$1" == *"){"* ]]; }
is_open_brace() { [[ "$1" =~ \{$ ]]; }
is_close_brace() { [[ "$1" =~ ^\} ]]; }
is_arrow_line() { [[ "$1" == *"=>"* ]]; }

# Align arrows
align_arrows() {
    local indent_level="$1"
    local maxkey=0
    local line key val

    # Determine max key length
    for line in "${BUFFER_ARROW_BLOCK[@]}"; do
        key="${line%%=>*}"
        key="$(strip "$key")"
        (( ${#key} > maxkey )) && maxkey=${#key}
    done

    # Print aligned lines
    for line in "${BUFFER_ARROW_BLOCK[@]}"; do
        if [[ "$line" == *"=>"* ]]; then
            key="${line%%=>*}"; key="$(strip "$key")"
            val="${line#*=>}"
            indent "$indent_level"
            printf "%-*s =>%s\n" "$maxkey" "$key" "$val"
        else
            indent "$indent_level"
            echo "$line"
        fi
    done

    BUFFER_ARROW_BLOCK=()
}

# Emit line with current indent
emit_line() {
    indent "$(stack_depth)"
    echo "$1"
}

###############################################################################
# MAIN LOOP
###############################################################################
FILE="$1"
[[ -z "$FILE" ]] && echo "Usage: $0 file.pp" && exit 1

while IFS= read -r raw || [[ -n "$raw" ]]; do
    line="$(strip "$raw")"

    [[ -z "$line" ]] && echo "" && continue

    #################################################
    # Class/define header state
    #################################################
    if (( IN_CLASS_HEADER == 1 )); then
        BUFFER_CLASS_HEADER+=("$raw")
        if ends_class_header_paren_and_brace "$line"; then
            # Complete header with { on same line
            for hl in "${BUFFER_CLASS_HEADER[@]}"; do emit_line "$hl"; done
            BUFFER_CLASS_HEADER=()
            push_indent $(( $(stack_depth) + INDENT ))
            IN_CLASS_HEADER=0
            EXPECTING_CLASS_BRACE=0
            continue
        elif ends_class_header_paren "$line"; then
            IN_CLASS_HEADER=0
            EXPECTING_CLASS_BRACE=1
            continue
        fi
        continue
    fi

    if (( EXPECTING_CLASS_BRACE == 1 )); then
        # If line is {, emit header then brace
        if is_open_brace "$line"; then
            for hl in "${BUFFER_CLASS_HEADER[@]}"; do emit_line "$hl"; done
            BUFFER_CLASS_HEADER=()
            emit_line "$raw"
            push_indent $(( $(stack_depth) + INDENT ))
            EXPECTING_CLASS_BRACE=0
            continue
        else
            # Insert missing {
            for hl in "${BUFFER_CLASS_HEADER[@]}"; do emit_line "$hl"; done
            BUFFER_CLASS_HEADER=()
            indent "$(stack_depth)"
            echo "{"
            push_indent $(( $(stack_depth) + INDENT ))
            EXPECTING_CLASS_BRACE=0
            # continue processing current line normally
        fi
    fi

    if is_class_define_start "$line"; then
        IN_CLASS_HEADER=1
        BUFFER_CLASS_HEADER=("$raw")
        continue
    fi

    #################################################
    # Arrow block handling
    #################################################
    if (( IN_ARROW_BLOCK == 1 )); then
        if is_arrow_line "$line"; then
            BUFFER_ARROW_BLOCK+=("$raw")
            continue
        else
            # End of arrow block
            align_arrows "$(stack_depth)"
            IN_ARROW_BLOCK=0
            # Fall through to process current line
        fi
    fi

    if is_arrow_line "$line"; then
        BUFFER_ARROW_BLOCK=("$raw")
        IN_ARROW_BLOCK=1
        continue
    fi

    #################################################
    # Braces
    #################################################
    if is_open_brace "$line"; then
        emit_line "$raw"
        push_indent $(( $(stack_depth) + INDENT ))
        continue
    elif is_close_brace "$line"; then
        pop_indent
        emit_line "$raw"
        continue
    fi

    #################################################
    # Normal line
    #################################################
    emit_line "$raw"

done < "$FILE"

# Flush any remaining arrow block at EOF
if (( IN_ARROW_BLOCK == 1 )); then
    align_arrows "$(stack_depth)"
fi
