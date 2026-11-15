#!/usr/bin/env bash
# Example config file for qb-buku.
#
# Installed automatically to $XDG_CONFIG_HOME/qb-buku/config.sh
# (or ~/.config/qb-buku/config.sh) by install.sh, if that file doesn't already exist.
#
# Uncomment and edit any line below to override the default.

# Command (and arguments) used to present a dmenu-style picker.
# Must read entries from stdin and print selected entries to stdout, one per line.
#DMENU_CMD=(rofi -dmenu -i -p "bookmark" -markup-rows -sep $'\x1f' -eh 3)

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

# Flag passed to DMENU_CMD to enable multi-select
# Like `DMENU_MSG_FLAG`, It is your responsibility to keep this matched to
# whatever `DMENU_CMD` you've configured — a mismatched pair will cause errors.
# Defaults to "-multi-select" only when DMENU_CMD is also left at its default (rofi).
#DMENU_MULTI_FLAG="-multi-select"

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

# Hook for adding tags automatically, based on rules you write in bash. Undefined by
# default; uncomment and edit the function below to enable it.
#
# When it runs:
#   Once for each bookmark *newly* added by buku-add or buku-add-all, after buku has
#   stored it -- so after any auto-fetched and user-supplied tags. It is not run for
#   bookmarks that already existed, for failed adds, or by buku-update. To apply
#   changed rules to your existing bookmarks, run buku-retag.
#
# What it can see:
#   BOOKMARK_URL     the stored URL
#   BOOKMARK_TITLE   the stored title (may be empty)
#   BOOKMARK_DOMAIN  the URL's host, lowercased, without scheme/user/port/path
#                    (e.g. "www.youtube.com")
#   BOOKMARK_TAGS    array of the bookmark's current tags, lowercased (buku stores
#                    all tags lowercase)
#
# Helpers:
#   add_tag TAG, ...      add each TAG (trimmed, lowercased) unless already present
#   has_tag TAG, ...      true if the bookmark has *all* of the given tags
#   has_any_tag TAG, ...  true if the bookmark has *any* of the given tags
#   domain_is DOMAIN...   true if BOOKMARK_DOMAIN is any DOMAIN or a subdomain of one
#                         (youtube.com matches www.youtube.com, not notyoutube.com)
#   Like buku, the tag helpers take a comma-separated list: their arguments are joined
#   with spaces, then split on commas, so multi-word tags need no quoting
#   (`add_tag camera phone,video` adds "camera phone" and "video"). domain_is takes
#   space-separated domains.
#   For titles/URLs use plain bash tests, e.g. [[ ${BOOKMARK_TITLE,,} == *"how to"* ]]
#   for a case-insensitive substring, or [[ $BOOKMARK_URL =~ regex ]] for a regex.
#
# Order matters:
#   The function is run exactly once, top to bottom. Tags added by add_tag are
#   visible to later has_tag/has_any_tag checks in the same run, so compound rules
#   that depend on other rules' tags must come *after* those rules.
#
#add_additional_tags() {
#    domain_is youtube.com youtu.be && add_tag youtube_video
#    [[ ${BOOKMARK_TITLE,,} == *"how to"* ]] && add_tag how_to
#    # Must come after any rule that can add youtube_video or course
#    has_tag youtube_video,course && add_tag educational
#}

# Extra flags passed to qutebrowser when buku-browse or buku-random launches it directly
# (i.e. when run outside of a running qutebrowser instance).
#QUTEBROWSER_FLAGS=()

# Extra environment variables (NAME=value) set for qutebrowser when buku-browse or
# buku-random launches it directly (i.e. when run outside of a running qutebrowser instance).
#QUTEBROWSER_ENV=()
