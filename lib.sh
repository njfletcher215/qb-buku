#!/usr/bin/env bash
# Shared helpers for qutebrowser userscripts

strip_ansi() { printf '%s' "$1" | sed 's/\x1b\[[0-9;]*[a-zA-Z]//g'; }

qute_error() {
    local msg="$1"
    if [[ -n "${QUTE_FIFO:-}" ]]; then
        printf "message-error \"%s, see ':process $$' for details\"\n" "$(strip_ansi "$msg")" >> "$QUTE_FIFO"
    fi
    echo "Error: $msg" >&2
}

qute_message() {
    local msg="$1"
    if [[ -n "${QUTE_FIFO:-}" ]]; then
        printf "message-info \"%s, see ':process $$' for details\"\n" "$(strip_ansi "$msg")" >> "$QUTE_FIFO"
    else
        echo "$msg"
    fi
}
