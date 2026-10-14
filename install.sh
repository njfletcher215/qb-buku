#!/usr/bin/env bash
set -euo pipefail

script_dir="$(dirname "$(realpath "$0")")"

# Prompt for a value with a default
prompt() {
    local msg="$1" default="$2" answer
    read -r -p "$msg [$default]: " answer
    printf '%s' "${answer:-$default}"
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

config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/qb-buku"
config_file="$config_dir/config.sh"
if [[ -f "$config_file" ]]; then
    echo "-> Config file already exists at '$config_file', leaving it untouched."
    echo "   (If the venv path changed, you may need to update PYTHON there manually.)"
else
    echo "-> Creating config file at '$config_file'..."
    mkdir -p "$config_dir"
    cp "$script_dir/config.example.sh" "$config_file"
    sed -i "s|^#PYTHON=.*|PYTHON=$venv_python|" "$config_file"
fi

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
echo "Keybindings can be prefixed with a leader key (e.g. ',m' instead of 'm')."
prefix=$(prompt "Keybinding prefix (enter 'none' to bind m/M/b/B directly)" ",")
[[ "$prefix" == "none" ]] && prefix=""

echo
python3 "$script_dir/install_configure.py" "$qb_config" "$prefix"

echo
echo "Done! Restart qutebrowser for the changes to take effect."
