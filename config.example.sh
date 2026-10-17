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
#DMENU_CMD=(rofi -dmenu -multi-select -i -p "bookmark" -markup-rows -sep $'\x1f' -eh 3)

# When true, automatically use '+' (append) mode when adding tags to a new bookmark,
# meaning tags will be fetched from the site itself, before merging in any user-provided tags.
# Has no effect if '+' or '-' is already passed explicitly.
# In buku-add's interactive mode, `false` prompts for the inclusion of autofetched tags,
# while `true` still appends them automatically
#AUTO_FETCH_TAGS=false

# The Python interpreter to use — must have the buku module installed.
# install.sh sets this to the venv interpreter automatically.
#PYTHON=/path/to/venv/bin/python3

# Template for showing a reminder message in the dmenu picker used by interactive
# buku-add, with '{message}' as the placeholder for the message text. Different pickers
# expose this differently (rofi: "-mesg {message}", fuzzel: "--mesg={message}"); leave
# this unset/empty to skip the message entirely (e.g. for plain dmenu, which has no
# message area). It is your responsibility to keep this matched to whatever DMENU_CMD
# you've configured — a mismatched pair will cause errors.
# Defaults to "-mesg {message}" only when DMENU_CMD is also left at its default (rofi).
#DMENU_MSG_FLAG="-mesg {message}"

# Whether pick_bookmarks() Pango-escapes (&, <, > -> &amp;, &lt;, &gt;) the
# title/url/tags values it substitutes into BOOKMARK_FORMAT, so arbitrary bookmark
# data can't break hand-written <span>/<i> markup.
#ESCAPE_PANGO=true

# Template controlling how each bookmark is displayed in the dmenu-style picker used
# by buku-browse/buku-delete, with these placeholders:
#   {title}  bookmark title (falls back to the url if the bookmark has no title)
#   {url}    bookmark url
#   {tags}   bookmark tags, always ", "-joined and trimmed, regardless of how they're
#            stored internally
#   {id}     buku's bookmark index/id
# The `BOOKMARK_FORMAT` *must* end in its delimiter (by default, `\n`).
#BOOKMARK_FORMAT=$'{title}\n<span foreground="#888888">{url}</span>\n<span foreground="#888888" size="small"><i>{tags}</i></span>\x1f'

# Extra flags passed to qutebrowser when buku-browse launches it directly
# (i.e. when run outside of a running qutebrowser instance).
#QUTEBROWSER_FLAGS=()

# Extra environment variables (NAME=value) set for qutebrowser when buku-browse
# launches it directly (i.e. when run outside of a running qutebrowser instance).
#QUTEBROWSER_ENV=()
