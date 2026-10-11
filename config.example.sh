#!/usr/bin/env bash
# Example config file for qb-buku.
#
# Installed automatically to $XDG_CONFIG_HOME/qb-buku/config.sh
# (or ~/.config/qb-buku/config.sh) by install.sh, if that file doesn't already exist.
#
# Uncomment and edit any line below to override the default.

# Command (and arguments) used to present a dmenu-style picker.
# Must read entries from stdin and print selected entries to stdout, one per line.
# In order to use multi-select, you must provide a command that supports it.
# rofi does so natively via the -multi-select flag,
# and dmenu does so when patched with suckless's multi-select
#DMENU_CMD=(rofi -dmenu -multi-select -i -p "bookmark")

# When true, automatically use '+' (append) mode when adding tags to a new bookmark,
# meaning tags will be fetched from the site itself, before merging in any user-provided tags.
# Has no effect if '+' or '-' is already passed explicitly.
#AUTO_FETCH_TAGS=false

# The Python interpreter to use — must have the buku module installed.
# install.sh sets this to the venv interpreter automatically.
#PYTHON=/path/to/venv/bin/python3
