#!/usr/bin/env bash
# ppfmt - Puppet manifest formatter (minimal style)
# Works on macOS Bash 3.2

###############################################################################
# Globals
###############################################################################

INDENT=2
declare -a ISTACK=("brace:0") # stack entries: type:depth (type = brace or paren)
BUFFER_CLASS_HEADER=()        # buffer lines for a class/define header
IN_CLASS_HEADER=0             # state flag
EXPECTING_CLASS_BRACE=0       # class header ended with ")", expecting possibly "{"

###############################################################################
# Utility functions
###############################################################################

indent() { printf "%*s" "$1" ""; }

stack_depth() {
  local last=$(( ${#ISTACK[@]} - 1 ))
  [[ $last -lt 0 ]] && echo 0 && return
  echo "${ISTACK[$last]#*:}"
}

stack_type() {
  local last=$(( ${#ISTACK[@]} - 1 ))
  [[ $last -lt 0 ]] && echo "brace" && return
  echo "${ISTACK[$last]%%:*}"
}

push_stack() {
  ISTACK+=("$1:$2")
}

pop_stack() {
  local last=$(( ${#ISTACK[@]} - 1 ))
  [[ $last -gt 0 ]] && unset "ISTACK[$last]"
}

is_open_brace() { [[ "$1" =~ \{$ ]]; }
is_close_brace() { [[ "$1" =~ ^\} ]]; }

is_open_paren() { [[ "$1" =~ \($ ]]; }
is_close_paren() { [[ "$1" =~ ^\) ]]; }

is_arrow_line() {
  [[ "$1" == *"=>"* ]]
}

strip() {
  echo "$1" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

###############################################################################
# Arrow Alignment: align any block containing multiple => lines
###############################################################################

align_arrows_block() {
  local indent_level="$1"

  local lines=("$@")
  unset lines[0]                # remove indent arg
  local block=("${lines[@]}")
  local maxkey=0

  # Measure max key length
  for ln in "${block[@]}"; do
    if [[ "$ln" == *"=>"* ]]; then
      local key="${ln%%=>*}"
      key="$(echo "$key" | sed 's/[[:space:]]*$//')"
      (( ${#key} > maxkey )) && maxkey=${#key}
    fi
  done

  # Print aligned
  for ln in "${block[@]}"; do
    indent "$indent_level"
    if [[ "$ln" == *"=>"* ]]; then
      local key="${ln%%=>*}"
      key="$(echo "$key" | sed 's/[[:space:]]*$//')"
      local val="${ln#*=>}"
      printf "%-*s =>%s\n" "$maxkey" "$key" "$val"
    else
      echo "$ln"
    fi
  done
}

###############################################################################
# Class/Define header handling (minimal normalization)
###############################################################################

is_class_or_define_start() {
  [[ "$1" =~ ^(class|define)[[:space:]]+([a-zA-Z0-9_:]+)[[:space:]]*\( ]]
}

ends_class_header_paren() {
  [[ "$1" == *")" ]] && [[ "$1" != *"{"* ]]
}

ends_class_header_paren_and_brace() {
  [[ "$1" == *"){"* ]]
}

###############################################################################
# Emit a single line with current indent
###############################################################################

emit_line() {
  local line="$1"
  indent "$(stack_depth)"
  echo "$line"
}

###############################################################################
# Main Logic
###############################################################################

process_input_line() {
  local raw="$1"
  local line="$(strip "$raw")"

  # empty
  [[ -z "$line" ]] && echo "" && return

  ###########################################################################
  # CLASS/DEFINE HEADER PROCESSING
  ###########################################################################

  if (( IN_CLASS_HEADER == 1 )); then
    BUFFER_CLASS_HEADER+=("$line")

    # Does line close params AND contain { ?
    if ends_class_header_paren_and_brace "$line"; then
      IN_CLASS_HEADER=0
      EXPECTING_CLASS_BRACE=0

      # Emit full header as-is
      for hl in "${BUFFER_CLASS_HEADER[@]}"; do
        emit_line "$hl"
      done
      BUFFER_CLASS_HEADER=()

      # Push brace indent
      push_stack "brace" $(( $(stack_depth) + INDENT ))
      return
    fi

    # Does line end params but no {?
    if ends_class_header_paren "$line"; then
      IN_CLASS_HEADER=0
      EXPECTING_CLASS_BRACE=1
      return
    fi

    return
  fi

  # If we just ended class header and expecting "{"
  if (( EXPECTING_CLASS_BRACE == 1 )); then
    # If current line is "{", emit header then brace
    if is_open_brace "$line"; then
      # Emit header exactly as user wrote
      for hl in "${BUFFER_CLASS_HEADER[@]}"; do
        emit_line "$hl"
      done

      BUFFER_CLASS_HEADER=()
      emit_line "$line"

      EXPECTING_CLASS_BRACE=0
      push_stack "brace" $(( $(stack_depth) + INDENT ))
      return
    else
      # No "{", user forgot. Emit header and insert {
      for hl in "${BUFFER_CLASS_HEADER[@]}"; do
        emit_line "$hl"
      done
      BUFFER_CLASS_HEADER=()

      # Insert brace (indented same as header)
      indent "$(stack_depth)"
      echo "{"
      push_stack "brace" $(( $(stack_depth) + INDENT ))

      # Now process this non-brace line normally
      EXPECTING_CLASS_BRACE=0
      # fall through
    fi
  fi

  # Detect new class/define header start
  if is_class_or_define_start "$line"; then
    IN_CLASS_HEADER=1
    BUFFER_CLASS_HEADER=("$line")
    return
  fi

  ###########################################################################
  # BLOCK CLOSING
  ###########################################################################

  if is_close_brace "$line"; then
    pop_stack
    emit_line "$line"
    return
  fi

  if is_close_paren "$line"; then
    if [[ "$(stack_type)" == "paren" ]]; then
      pop_stack
    fi
    emit_line "$line"
    return
  fi

  ###########################################################################
  # ARROW BLOCK DETECTION
  ###########################################################################

  if is_arrow_line "$line"; then
    local block=("$line")

    # Read ahead for additional arrow lines
    while IFS= read -r next_raw; do
      local next="$(strip "$next_raw")"
      if [[ -z "$next" ]] || ! is_arrow_line "$next"; then
        # End of block — process gathered lines
        local depth="$(stack_depth)"
        align_arrows_block "$depth" "${block[@]}"

        # Output the non-arrow line after returning to main read loop
        NEXT_BUFFER="$next_raw"
        return 1
      fi
      block+=("$next")
    done

    # EOF reached with arrow lines only
    local depth="$(stack_depth)"
    align_arrows_block "$depth" "${block[@]}"
    return
  fi

  ###########################################################################
  # NORMAL LINE
  ###########################################################################

  emit_line "$line"

  if is_open_brace "$line"; then
    push_stack "brace" $(( $(stack_depth) + INDENT ))
  elif is_open_paren "$line"; then
    push_stack "paren" $(( $(stack_depth) + INDENT ))
  fi
}

###############################################################################
# MAIN LOOP
###############################################################################

NEXT_BUFFER=""
while true; do
  if [[ -n "$NEXT_BUFFER" ]]; then
    raw="$NEXT_BUFFER"
    NEXT_BUFFER=""
  else
    IFS= read -r raw || break
  fi

  process_input_line "$raw"
  rc=$?
  if [[ $rc -eq 1 ]]; then
    # consumed arrow block, NEXT_BUFFER holds next non-arrow line
    continue
  fi
done
