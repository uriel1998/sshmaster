#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CONFIG_FILE="${SSHM_CONFIG:-$SCRIPT_DIR/sshm.config}"
ICON_DIR="${SSHM_ICON_DIR:-$SCRIPT_DIR/share/icons}"

trim() {
    local value="$1"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "$value"
}

xterm_256_to_hex() {
    local color="$1"
    local component
    local -a cube=(0 95 135 175 215 255)

    if ! [[ "$color" =~ ^[0-9]+$ ]] || [ "$color" -lt 0 ] || [ "$color" -gt 255 ]; then
        return 1
    fi

    if [ "$color" -lt 16 ]; then
        case "$color" in
            0) printf '#000000\n' ;;
            1) printf '#800000\n' ;;
            2) printf '#008000\n' ;;
            3) printf '#808000\n' ;;
            4) printf '#000080\n' ;;
            5) printf '#800080\n' ;;
            6) printf '#008080\n' ;;
            7) printf '#c0c0c0\n' ;;
            8) printf '#808080\n' ;;
            9) printf '#ff0000\n' ;;
            10) printf '#00ff00\n' ;;
            11) printf '#ffff00\n' ;;
            12) printf '#0000ff\n' ;;
            13) printf '#ff00ff\n' ;;
            14) printf '#00ffff\n' ;;
            15) printf '#ffffff\n' ;;
        esac
        return 0
    fi

    if [ "$color" -le 231 ]; then
        color=$((color - 16))
        printf '#%02x%02x%02x\n' \
            "${cube[color / 36]}" \
            "${cube[(color % 36) / 6]}" \
            "${cube[color % 6]}"
        return 0
    fi

    component=$((8 + (color - 232) * 10))
    printf '#%02x%02x%02x\n' "$component" "$component" "$component"
}

normalize_xterm_color() {
    local color="$1"

    if [ -z "$color" ]; then
        return 1
    fi

    if xterm_256_to_hex "$color" 2>/dev/null; then
        return 0
    fi

    printf '%s\n' "$color"
}

extract_destination() {
    local token opt needs_arg
    local -a args=("$@")
    local short_with_arg="Bb:c:D:E:e:F:I:i:J:L:l:m:O:o:p:Q:R:S:W:w:"
    local end_of_options=0
    local i=0

    while [ $i -lt ${#args[@]} ]; do
        token="${args[$i]}"

        if [ $end_of_options -eq 1 ]; then
            printf '%s\n' "$token"
            return 0
        fi

        if [ "$token" = "--" ]; then
            end_of_options=1
            i=$((i + 1))
            continue
        fi

        if [[ "$token" != -* || "$token" = "-" ]]; then
            printf '%s\n' "$token"
            return 0
        fi

        if [[ "$token" == -* && "$token" != --* ]]; then
            local j=1
            while [ $j -lt ${#token} ]; do
                opt="${token:$j:1}"
                needs_arg=0
                if [[ "$short_with_arg" == *"$opt:"* ]]; then
                    needs_arg=1
                fi

                if [ $needs_arg -eq 1 ]; then
                    if [ $((j + 1)) -lt ${#token} ]; then
                        break
                    fi
                    i=$((i + 1))
                    break
                fi

                j=$((j + 1))
            done
        fi

        i=$((i + 1))
    done

    return 1
}

config_for_host() {
    local target="$1"
    local line key value trimmed
    local matched=0
    local icon=""
    local bg=""
    local fg=""

    [ -f "$CONFIG_FILE" ] || return 1

    while IFS= read -r line || [ -n "$line" ]; do
        trimmed=$(trim "$line")

        if [[ "$trimmed" == \#* ]]; then
            if [ $matched -eq 1 ]; then
                printf 'ICON=%s\n' "$icon"
                printf 'BGCOLOR=%s\n' "$bg"
                printf 'FGCOLOR=%s\n' "$fg"
                return 0
            fi
            matched=0
            icon=""
            bg=""
            fg=""
            continue
        fi

        [ -n "$trimmed" ] || continue

        key=${trimmed%%[[:space:]]*}
        value=$(trim "${trimmed#"$key"}")

        case "$key" in
            Host)
                if [ "$value" = "$target" ]; then
                    matched=1
                fi
                ;;
            Icon)
                if [ $matched -eq 1 ] && [ -z "$icon" ]; then
                    icon="$value"
                fi
                ;;
            BGColor)
                if [ $matched -eq 1 ] && [ -z "$bg" ]; then
                    bg="$value"
                fi
                ;;
            FGColor)
                if [ $matched -eq 1 ] && [ -z "$fg" ]; then
                    fg="$value"
                fi
                ;;
        esac
    done < "$CONFIG_FILE"

    if [ $matched -eq 1 ]; then
        printf 'ICON=%s\n' "$icon"
        printf 'BGCOLOR=%s\n' "$bg"
        printf 'FGCOLOR=%s\n' "$fg"
        return 0
    fi

    return 1
}

resolve_icon_path() {
    local icon_value="$1"

    [ -n "$icon_value" ] || return 1

    if [ -f "$icon_value" ]; then
        printf '%s\n' "$icon_value"
        return 0
    fi

    if [ -f "$ICON_DIR/$icon_value" ]; then
        printf '%s\n' "$ICON_DIR/$icon_value"
        return 0
    fi

    if [ -f "$ICON_DIR/$icon_value.png" ]; then
        printf '%s\n' "$ICON_DIR/$icon_value.png"
        return 0
    fi

    return 1
}

main() {
    local destination host_match config_data icon="" bg="" fg="" icon_path=""
    local key value
    local -a xterm_args

    if ! destination=$(extract_destination "$@"); then
        exec ssh "$@"
    fi

    host_match="${destination##*@}"

    if ! config_data=$(config_for_host "$host_match"); then
        exec ssh "$@"
    fi

    while IFS='=' read -r key value; do
        case "$key" in
            ICON)
                icon="$value"
                ;;
            BGCOLOR)
                bg="$value"
                ;;
            FGCOLOR)
                fg="$value"
                ;;
        esac
    done <<< "$config_data"

    xterm_args=(-T "$host_match" -tn xterm-256color)

    if [ -n "$bg" ]; then
        xterm_args+=(-bg "$(normalize_xterm_color "$bg")")
    fi

    if [ -n "$fg" ]; then
        xterm_args+=(-fg "$(normalize_xterm_color "$fg")")
    fi

    if icon_path=$(resolve_icon_path "$icon" 2>/dev/null); then
        xterm_args+=(
            -e
            bash
            -lc
            'if command -v xseticon >/dev/null 2>&1 && [ -n "${WINDOWID:-}" ] && [ -f "$1" ]; then xseticon -id "$WINDOWID" "$1" >/dev/null 2>&1 || true; fi; shift; exec ssh "$@"'
            bash
            "$icon_path"
            "$@"
        )
    else
        if [ -n "$icon" ]; then
            printf 'sshm.sh: icon "%s" not found under %s\n' "$icon" "$ICON_DIR" >&2
        fi
        xterm_args+=(-e ssh "$@")
    fi

    exec xterm "${xterm_args[@]}"
}

main "$@"
