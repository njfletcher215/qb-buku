#!/usr/bin/env bash
set -euo pipefail

script_dir="$(dirname "$(realpath "$0")")"

# Prompt for a value with a default
prompt() {
    local msg="$1" default="$2" answer
    read -r -p "$msg [$default]: " answer
    printf '%s' "${answer:-$default}"
}

# Yes/no prompt; returns 0 for yes, 1 for no
confirm() {
    local msg="$1" default="${2:-n}" answer
    read -r -p "$msg [${default}]: " answer
    [[ "${answer:-$default}" =~ ^[Yy] ]]
}

# Expand a leading ~ in a path
expand_path() { printf '%s' "${1/#\~/$HOME}"; }

echo "=== qb-buku installer ==="
echo

# ---------------------------------------------------------------------------
# 1. Python venv (for 'import buku' in get-id-by-url.py)
# ---------------------------------------------------------------------------
venv_path=$(prompt "Python venv path" "$script_dir/venv")
venv_path="$(expand_path "$venv_path")"
[[ "$venv_path" != /* ]] && venv_path="$PWD/$venv_path"

if [[ -d "$venv_path" ]]; then
    echo "-> Found existing directory at '$venv_path', assuming existing venv."
else
    echo "-> Creating venv at '$venv_path'..."
    python3 -m venv "$venv_path"
fi

echo "-> Installing buku Python module..."
"$venv_path/bin/pip" install --quiet buku

venv_python="$venv_path/bin/python3"
echo "-> Setting PYTHON in config.sh..."
sed -i "s|^PYTHON=.*|PYTHON=$venv_python|" "$script_dir/config.sh"

echo

# ---------------------------------------------------------------------------
# 2. Userscript symlinks
# ---------------------------------------------------------------------------
echo "Where should the userscript symlinks be placed?"
echo "  Typical locations:"
echo "    ~/.config/qutebrowser/userscripts  (default)"
echo "    ~/.local/share/qutebrowser/userscripts"
echo "    /usr/share/qutebrowser/userscripts"
echo
userscripts_dir=$(prompt "Userscripts directory" "~/.config/qutebrowser/userscripts")
userscripts_dir="$(expand_path "$userscripts_dir")"
mkdir -p "$userscripts_dir"

for script in add delete update browse; do
    src="$script_dir/${script}.sh"
    dest="$userscripts_dir/buku-${script}"
    if [[ -L "$dest" ]]; then
        ln -sf "$src" "$dest"
        echo "-> Updated symlink: $dest"
    elif [[ -e "$dest" ]]; then
        echo "-> Warning: '$dest' already exists and is not a symlink, skipping."
    else
        ln -s "$src" "$dest"
        echo "-> Created symlink: $dest"
    fi
done

echo

# ---------------------------------------------------------------------------
# 3. qutebrowser config.py — aliases and keybindings
# ---------------------------------------------------------------------------
qb_config=$(prompt "qutebrowser config.py path" "~/.config/qutebrowser/config.py")
qb_config="$(expand_path "$qb_config")"

echo
if confirm "Override qutebrowser's built-in bookmark bindings? (uses m/M/b/B instead of ,m/,M/,b/,B)" "n"; then
    prefix=""
else
    prefix=","
fi

aliases_block=$(cat <<'PYEOF'

# qb-buku aliases
c.aliases.update({
    'buku-add':    'spawn --userscript buku-add',
    'buku-delete': 'spawn --userscript buku-delete',
    'buku-update': 'spawn --userscript buku-update',
    'buku-browse': 'spawn --userscript buku-browse',
})
PYEOF
)

bindings_block=$(cat <<PYEOF

# qb-buku keybindings
config.bind('${prefix}m', 'spawn --userscript buku-add')
config.bind('${prefix}M', 'spawn --userscript buku-delete')
config.bind('${prefix}b', 'spawn --userscript buku-browse')
config.bind('${prefix}B', 'spawn --userscript buku-browse -t')
PYEOF
)

if [[ -f "$qb_config" ]]; then
    echo "-> Appending to '$qb_config'..."
    printf '%s\n%s\n' "$aliases_block" "$bindings_block" >> "$qb_config"
else
    echo "-> Creating '$qb_config'..."
    mkdir -p "$(dirname "$qb_config")"
    { printf 'config.load_autoconfig()\n'; printf '%s\n%s\n' "$aliases_block" "$bindings_block"; } > "$qb_config"
fi

echo
echo "Done! Restart qutebrowser for the changes to take effect."
