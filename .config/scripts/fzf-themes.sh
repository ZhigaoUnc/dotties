#!/usr/bin/env bash
set -euo pipefail

FZF_THEME_BASE=(
    --color=bw
    --height=70%
    --margin=10%,20%,20%,20%
    --layout=reverse
    --info=hidden
)

FZF_THEME_PDF=("${FZF_THEME_BASE[@]}")

FZF_THEME_SESSION=("${FZF_THEME_BASE[@]}" --scheme=path)

FZF_THEME_LINKS=("${FZF_THEME_BASE[@]}" --cycle)

fzf_theme_flags() {
    local theme="${1:-}"
    local upper_theme="${theme^^}"
    local var_name="FZF_THEME_${upper_theme}"
    if ! declare -p "${var_name}" >/dev/null 2>&1; then
        return 1
    fi
    local -n flags="${var_name}"
    printf '%s\n' "${flags[@]}"
}
