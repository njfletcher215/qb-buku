# qb-buku

qutebrowser userscripts for managing [buku](https://github.com/jarun/buku) bookmarks.

## Scripts

| Script | Description |
|---|---|
| `add.sh` | Bookmark the current page (or a given URL) |
| `add-all.sh` | Bookmark every open tab (or several given URLs) with a shared title prefix and tags |
| `delete.sh` | Delete one or more bookmarks by index, range, or URL |
| `update.sh` | Update a bookmark's URL, title, or tags (or interactively via a dmenu picker) |
| `browse.sh` | Browse and open bookmarks via a dmenu-style picker |
| `retag.sh` | Apply [`add_additional_tags`](#add_additional_tags) to existing bookmarks |
| `random.sh` | Open one or more random bookmarks, optionally filtered by tags, domain, or title |

## Dependencies

- [buku](https://github.com/jarun/buku) — installed system-wide via your package manager
- [jq](https://jqlang.org) — used by `browse.sh`, `delete.sh`, `update.sh`, `add-all.sh`, `retag.sh`, and `random.sh`, and by `add.sh` when [`add_additional_tags`](#add_additional_tags) is defined
- Python 3 with the `buku` module importable — used by `delete.sh` and `update.sh` (and by `add.sh`/`add-all.sh` when [`add_additional_tags`](#add_additional_tags) is defined) to resolve URLs to bookmark IDs; `install.sh` sets up a venv for this automatically
- [yq](https://github.com/kislyuk/yq) — used by `add-all.sh` to read qutebrowser's session files
- A dmenu-compatible picker — see [Configuration](#configuration)

## Installation

### Via install script (recommended)

```sh
$ git clone https://github.com/you/qb-buku ~/qb-buku
$ cd ~/qb-buku && ./install.sh
```

### Manual installation

1. Clone or download this repository somewhere permanent:

   ```sh
   git clone https://github.com/you/qb-buku ~/qb-buku
   ```

2. Create a venv and install the `buku` Python module:

   ```sh
   python3 -m venv ~/qb-buku/venv
   ~/qb-buku/venv/bin/pip install buku
   ```

3. Copy the example config to your XDG config directory and set `PYTHON` to the venv
   interpreter:

   ```sh
   mkdir -p ~/.config/qb-buku
   cp config.example.sh ~/.config/qb-buku/config.sh
   ```

   Then uncomment and edit the `PYTHON` line in `~/.config/qb-buku/config.sh`:

   ```sh
   PYTHON=/home/you/.local/share/qb-buku/venv/bin/python3
   ```

4. Symlink the scripts into your qutebrowser userscripts directory:

   ```sh
   userscripts=~/.config/qutebrowser/userscripts
   src=~/qb-buku

   mkdir -p "$userscripts"
   ln -s "$src/add.sh"     "$userscripts/buku-add"
   ln -s "$src/add-all.sh" "$userscripts/buku-add-all"
   ln -s "$src/delete.sh"  "$userscripts/buku-delete"
   ln -s "$src/update.sh"  "$userscripts/buku-update"
   ln -s "$src/browse.sh"  "$userscripts/buku-browse"
   ln -s "$src/retag.sh"   "$userscripts/buku-retag"
   ln -s "$src/random.sh"  "$userscripts/buku-random"
   ```

5. Add the following to your `~/.config/qutebrowser/config.py`:

   ```python
   # qb-buku aliases
   c.aliases.update({
       'buku-add':     'spawn --userscript buku-add',
       'buku-add-all': 'spawn --userscript buku-add-all',
       'buku-delete':  'spawn --userscript buku-delete',
       'buku-update':  'spawn --userscript buku-update',
       'buku-browse':  'spawn --userscript buku-browse',
       'buku-retag':   'spawn --userscript buku-retag',
       'buku-random':  'spawn --userscript buku-random',
   })

   # qb-buku keybindings
   config.bind(',m', 'spawn --userscript buku-add')
   config.bind(',M', 'spawn --userscript buku-delete')
   config.bind(',b', 'spawn --userscript buku-browse')
   config.bind(',B', 'spawn --userscript buku-browse -t')
   ```

   Replace `,m`/`,M`/`,b`/`,B` with `m`/`M`/`b`/`B` if you want to override
   qutebrowser's built-in bookmark bindings.

## Configuration

Edit `~/.config/qb-buku/config.sh` (or `$XDG_CONFIG_HOME/qb-buku/config.sh`). `install.sh`
generates this file from `config.example.sh` on first install, leaving it untouched on
subsequent runs.

### `DMENU_CMD`

The picker command, as a bash array. It must read lines from stdin and print selected
lines to stdout, one per line.

```bash
# rofi with markup rendering and 3-line rows (default)
DMENU_CMD=(rofi -dmenu -i -p "bookmark" -markup-rows -sep $'\x1f' -eh 3)

# fuzzel
DMENU_CMD=(fuzzel --dmenu -p "bookmark")

# dmenu
DMENU_CMD=(dmenu -i -p "bookmark")
```

Can be overridden per-invocation with `buku-browse`'s, `buku-delete`'s,
`buku-update`'s, or `buku-random`'s `--dmenu-invocation <cmd>` flag.

You are responsible for ensuring that all required flags for your chosen dmenu-style picker are present. For example, if you inlucde pango markup in your `BOOKMARK_FORMAT`, you may have to pass a flag indicating the rows are styled (in `rofi`'s case, `-markup-rows`).

### `ESCAPE_PANGO`

Whether `pick_bookmarks()` Pango-escapes (`&`, `<`, `>` → `&amp;`, `&lt;`, `&gt;`) the
title/url/tags values it substitutes into `BOOKMARK_FORMAT`, so arbitrary bookmark
data can't break hand-written `<span>`/`<i>` markup.

```bash
ESCAPE_PANGO=true   # default -- needed if BOOKMARK_FORMAT uses Pango markup
ESCAPE_PANGO=false  # for a plain-text BOOKMARK_FORMAT/picker
```

### `BOOKMARK_FORMAT`

Template controlling how each bookmark is displayed in the picker used by
`buku-browse`/`buku-delete`, with these placeholders:

- `{title}` — bookmark title (falls back to the url if the bookmark has no title)
- `{url}` — bookmark url
- `{tags}` — bookmark tags, always `", "`-joined and trimmed, regardless of how buku
  stores them internally
- `{id}` — buku's bookmark index/id

```bash
# Styled, 3-line layout: title, then a dimmed url, then dimmed+small+italic tags
BOOKMARK_FORMAT=$'{title}\n<span foreground="#888888">{url}</span>\n<span foreground="#888888" size="small"><i>{tags}</i></span>\x1f'

# Plain layout
BOOKMARK_FORMAT=$'{title}\t{url}\n'
```

If neither `DMENU_CMD` nor `BOOKMARK_FORMAT` is set, `BOOKMARK_FORMAT` defaults to the
styled layout above (which is valid with `rofi -dmenu -markup-rows`); if `DMENU_CMD` is customized, it defaults to the plain layout
instead, so if your dmenu-style picker implements pango markup, be sure to overwrite `BOOKMARK_FORMAT`.

The `BOOKMARK_FORMAT` *must* end in its delimiter (by default, `\n`).

### `AUTO_FETCH_TAGS`

When `true`, `buku-add` automatically passes `+` to buku when tags are provided, so
buku fetches tags from the page itself and merges them with any tags you supply. Has no
effect when `+` or `-` is already given explicitly.

```bash
AUTO_FETCH_TAGS=true   # fetch and merge tags automatically
AUTO_FETCH_TAGS=false  # only use explicitly provided tags (default)
```

Can be overridden per-invocation with `buku-add`'s `--auto-fetch-tags[=<true|false>]`
flag (bare `--auto-fetch-tags` means `true`).

In interactive `buku-add` (see [Usage](#usage)), `AUTO_FETCH_TAGS=true` instead skips
the tag-picker step entirely and uses the fetched tags as-is, showing them as a reminder
when prompting for any extra tags. `AUTO_FETCH_TAGS=false` shows the picker so you can
choose which fetched tags to include.

### `DMENU_MSG_FLAG`

Template for showing a reminder message in the picker used by interactive `buku-add`,
with `{message}` as the placeholder for the message text. Different pickers expose this
differently:

```bash
# rofi
DMENU_MSG_FLAG="-mesg {message}"

# fuzzel
DMENU_MSG_FLAG="--mesg={message}"
```

If your dmenu-style picker does not implement a message field (`dmenu` itself does not), leave `DMENU_MSG_FLAG` empty. It is your responsibility to ensure that the `DMENU_MSG_FLAG` actually matches the expected format for the chosen `DMENU_CMD` -- mismatched values will cause errors.

If neither `DMENU_CMD` nor `DMENU_MSG_FLAG` is set, `DMENU_MSG_FLAG` will default to `-mesg {message}` (the rofi format), so it will work with the default `DMENU_CMD` (which is rofi).

### `DMENU_MULTI_FLAG`

Flag(s) passed to `DMENU_CMD` to enable multi-select, used only where selecting multiple
entries actually does something useful: `buku-browse -t`'s bookmark picker,
`buku-delete -d`'s bookmark picker, the tag-selection steps of interactive
`buku-add` and `buku-update -d`, and interactive `buku-random`'s tag picker. Different pickers expose this differently:

```bash
# rofi
DMENU_MULTI_FLAG="-multi-select"
```

[rofi](https://github.com/davatorium/rofi) supports multi-select natively via the
`-multi-select` flag. [dmenu](https://tools.suckless.org/dmenu/) supports it when built
with the [multi-select patch](https://tools.suckless.org/dmenu/patches/multi-select/).

If your dmenu-style picker does not support multi-select (plain `dmenu` does not unless
patched), leave `DMENU_MULTI_FLAG` empty — anywhere multi-select would otherwise be used,
it's skipped instead (see each command's docs below for exactly what that means there).
It is your responsibility to ensure that `DMENU_MULTI_FLAG` actually matches the expected
flag for the chosen `DMENU_CMD` -- a mismatched value will cause errors.

If neither `DMENU_CMD` nor `DMENU_MULTI_FLAG` is set, `DMENU_MULTI_FLAG` will default to
`-multi-select` (the rofi format), so it will work with the default `DMENU_CMD` (which is
rofi).

### `PYTHON`

Path to the Python interpreter that has the `buku` module installed. Set automatically
by `install.sh`.

```bash
PYTHON=/home/you/.local/share/qb-buku/venv/bin/python3
```

Can be overridden per-invocation with `buku-delete`'s or `buku-update`'s
`--python-invocation <path>` flag.

### `add_additional_tags`

An optional bash function that adds tags automatically, based on rules you write in
bash. It is unset by default. An example can be found below, or in `config.example.sh`.

```bash
add_additional_tags() {
    domain_is youtube.com youtu.be && add_tag youtube_video
    [[ ${BOOKMARK_TITLE,,} == *"how to"* ]] && add_tag how_to
    # Must come after any rule that can add youtube_video or course
    has_tag youtube_video,course && add_tag educational
}
```

#### When it runs

Once for each new bookmark added (via `buku-add` or `buku-add-all`).
It runs after all other tag selection, so it sees
[auto-fetched](#auto_fetch_tags) and the user-supplied tags.

After changing your rules, run [`buku-retag`](#buku-retag) to apply them to your
existing bookmarks too.

#### Variables

| Variable | Contents |
|---|---|
| `BOOKMARK_URL` | The stored URL |
| `BOOKMARK_TITLE` | The stored title (may be empty) |
| `BOOKMARK_DOMAIN` | The URL's host, lowercased, without scheme, user, port, or path (e.g. `www.youtube.com`) |
| `BOOKMARK_TAGS` | Array of the bookmark's current tags, lowercased (buku stores all tags in lowercase) |

#### Helpers

| Helper | Behavior |
|---|---|
| `add_tag TAG, ...` | Adds each `TAG` (trimmed, lowercased) unless the bookmark already has it |
| `has_tag TAG, ...` | True if the bookmark has **all** of the given tags (case-insensitive) |
| `has_any_tag TAG, ...` | True if the bookmark has **any** of the given tags (case-insensitive) |
| `domain_is DOMAIN...` | True if `BOOKMARK_DOMAIN` is any `DOMAIN` or a subdomain of one: `youtube.com` matches `youtube.com` and `www.youtube.com`, but not `notyoutube.com` |

For titles and URLs, use plain bash tests:

```bash
[[ ${BOOKMARK_TITLE,,} == *"how to"* ]]           # case-insensitive substring
[[ $BOOKMARK_URL =~ ^https://github\.com/[^/]+/[^/]+/issues/ ]]  # regex
```

Like buku, `add_tag`, `has_tag`, and `has_any_tag` take a **comma-separated** list of
tags: their arguments are joined with spaces, then split on commas. Multi-word tags need
no quoting, and tags can't contain commas:

```bash
add_tag camera phone,video      # adds "camera phone" and "video"
has_tag "camera phone"          # same as: has_tag camera phone
has_any_tag music,podcast       # true if either tag is present
```

`domain_is`, unlike the tag helpers, takes space-separated domains.

#### Order and compound rules

The function runs **exactly once**, top to bottom. Tags added with `add_tag` are visible
right away to later `has_tag`/`has_any_tag` checks in the same run. So a rule that
depends on tags other rules add (like `educational` above, which needs `youtube_video`)
must come *after* those rules. Combine conditions with ordinary bash `&&`, `||`, `!`,
`if`, and `case`:

```bash
add_additional_tags() {
    domain_is youtube.com youtu.be && add_tag youtube_video
    if has_tag youtube_video && ! has_any_tag music,podcast; then
        add_tag watch_later
    fi
}
```

### `QUTEBROWSER_FLAGS`

Extra flags passed to `qutebrowser` when `buku-browse` or `buku-random` launches it directly (i.e. when
run outside of a running qutebrowser instance). Empty by default.

```bash
QUTEBROWSER_FLAGS=(--backend webengine)
```

### `QUTEBROWSER_ENV`

Extra environment variables set for `qutebrowser` when `buku-browse` or `buku-random`
launches it directly (i.e. when run outside of a running qutebrowser instance). Empty by default.

```bash
# Always use the Fusion Qt style, regardless of system settings
QUTEBROWSER_ENV=(QT_STYLE_OVERRIDE=Fusion)
```

## Usage

### `buku-add`

```
:buku-add [--auto-fetch-tags[=<true|false>]] [-q|--quiet] [URL] [--title <title>] [+|-] [tag, ...]
```

Bookmark the current page. Invoked with no arguments (or just `-q`/`--quiet`), this falls
back to the current page's URL — see [Interactive `buku-add`](#interactive-buku-add)
below. An explicit `URL` is required for anything else (`--title`, `+`/`-`, or tags),
and always makes the invocation non-interactive: pass `--title <title>` to set the
bookmark's title (otherwise buku fetches it from the page), and any remaining arguments
are a comma-separated list of tags. The '+' modifier first fetches any tags from the
page itself, then appends any user-specified tags. The '-' modifier does the same, but
removes any user-specified tags from the fetched set instead.

```
:buku-add --quiet
:buku-add https://example.com --title "My Title"
:buku-add https://example.com + python,tools
:buku-add https://example.com - python,tools
:buku-add https://example.com --title "My Title" + python,tools
```

### Interactive `buku-add`

When invoked with **no URL** (e.g. bound to a qutebrowser key — the usual case), and
without `-q`/`--quiet`, `buku-add` fetches the page's title and tags itself, then walks
you through them interactively via the configured picker (see
[`DMENU_CMD`](#dmenu_cmd)):

1. A prompt for the title, pre-filled with the page's own title — accept it or type your
   own.
2. If [`AUTO_FETCH_TAGS`](#auto_fetch_tags) is `false` and
   [`DMENU_MULTI_FLAG`](#dmenu_multi_flag) is set, a multi-select prompt over the page's
   fetched tags, letting you choose which ones to include. If `AUTO_FETCH_TAGS` is `true`,
   or `DMENU_MULTI_FLAG` is empty (no way to pick a subset), this step is skipped and all
   fetched tags are included automatically.
3. A free-text prompt for any extra tags (comma-separated; unlike the CLI's positional tags, multi-word tags need no quoting here).
   If the [`DMENU_MSG_FLAG`](#dmenu_msg_flag) is set, a message
   reminding you which tags are already included, from step 2 or the auto-fetched set, will be displayed.

Cancelling any of these prompts aborts the add.

```
:buku-add
```

Interactive or not, if [`add_additional_tags`](#add_additional_tags) is defined, it is
run once the bookmark has been added, and any tags it adds are shown in the "Added"
message.

### `buku-add-all`

```
:buku-add-all [--windows <active|non-private|all>] [--prefix <prefix>] [--tags <tag, ...>]
              [--auto-fetch-tags[=<true|false>]] [-q|--quiet] [URL ...]
```

Bookmark every open tab at once, giving all of them the same title prefix and tags.
`buku-add-all` asks qutebrowser to save a temporary internal session,
reads each tab's current URL and title from it, and then deletes the session file.
Only `http(s)://` and `ftp(s)://` tabs are added.

`--windows` chooses which windows to collect tabs from:

- `active` (default): only the window `buku-add-all` was run from (even if private)
- `non-private`: every window except private ones
- `all`: every window, private ones included

`--prefix` is prepended to every title (e.g. `--prefix "Research: "`).
`--tags` is a comma-separated list of tags added to every bookmark.

If [`AUTO_FETCH_TAGS`](#auto_fetch_tags) (or `--auto-fetch-tags`) is `true`, each page's
own tags are fetched and your tags are appended to them, like `buku-add`. If it's
`false`, nothing is fetched and each bookmark gets only your tags.

Unless `-q`/`--quiet` is given, any of the prefix or tags that weren't passed on the
command line are prompted for through the configured picker:

1. A free-text prompt for the title prefix. Leave it empty for no prefix.
2. A free-text prompt for the tags (comma-separated). Leave it empty for no tags.

Cancelling either prompt aborts the run.

If given explicit `URL`s, `buku-add-all` bookmarks those instead of any open tabs
(regardless of whether it is being run as a qutebrowser userscript or via the command line)
and does not trigger the interactive prompts.

```
:buku-add-all
:buku-add-all --windows all
:buku-add-all -q --prefix "Research: " --tags papers,todo
$ add-all.sh --prefix "Research: " --tags papers https://example.com https://example.org
```

If [`add_additional_tags`](#add_additional_tags) is defined, it is run for each newly
added bookmark, and any tags it adds are listed per URL in the output.

### `buku-delete`

```
:buku-delete [--python-invocation <path>] [-d|--use-dmenu] [--dmenu-invocation <cmd>] [(index|N-M|URL) ...]
```

Delete one or more bookmarks. With no arguments, deletes the bookmark for the current
page. Accepts any mix of buku indices, `N-M` ranges, and exact URLs — multiple of each
can be combined in one call, and ranges are expanded locally so several ranges can be
passed together. Pass `-d`/`--use-dmenu` instead of any arguments to pick the
bookmark(s) to delete via the dmenu-style picker; with
[`DMENU_MULTI_FLAG`](#dmenu_multi_flag) set, you can select multiple bookmarks at once.

```
:buku-delete
:buku-delete 42
:buku-delete 10-20
:buku-delete 10-20 42 60-65
:buku-delete https://example.com
:buku-delete -d
```

### `buku-update`

```
:buku-update [--python-invocation <path>] <index|URL> url <new-url>
:buku-update [--python-invocation <path>] <index|URL> title <new-title>
:buku-update [--python-invocation <path>] <index|URL> tags [+|-] <tag, ...>
:buku-update [--python-invocation <path>] -d|--use-dmenu [--dmenu-invocation <cmd>] [<index|URL>]
```

Update a specific field of a bookmark, identified by index or exact URL.

```
:buku-update 7 title My Revised Title
:buku-update 7 url https://new-url.com
:buku-update 7 tags + newtag
:buku-update https://example.com tags - oldtag
```

#### Interactive `buku-update`

Pass `-d`/`--use-dmenu` to update a bookmark's title and tags together via the
configured picker, similar to interactive `buku-add`:

1. If `<index|URL>` isn't given, a single-select prompt over all bookmarks (see
   `buku-browse`) picks which one to update.
2. A prompt for the title, pre-filled with the bookmark's current title — accept it or
   type your own.
3. If [`DMENU_MULTI_FLAG`](#dmenu_multi_flag) is set, a multi-select prompt over the
   bookmark's current tags, letting you choose which to keep. If it's empty (no way to
   pick a subset), this step is skipped and all current tags are kept.
4. If `DMENU_MULTI_FLAG` is set, a multi-select prompt over every tag already used
   elsewhere in your bookmarks (excluding ones already kept), letting you pick more to
   add. Skipped if `DMENU_MULTI_FLAG` is empty.
5. A free-text prompt for any brand new tags (comma-separated). If
   [`DMENU_MSG_FLAG`](#dmenu_msg_flag) is set, a message reminding you which tags are
   already selected (from steps 3 and 4) will be displayed.

Cancelling any of these prompts aborts the update.

```
:buku-update -d
:buku-update -d 7
```

### `buku-browse`

```
:buku-browse [-t] [--dmenu-invocation <cmd>]
```

Open the picker populated with all bookmarks. Pass `-t` to open the first selection in
a new tab (all subsequent selections always open in new tabs regardless); this also
enables multi-select (see below) in the picker, since without `-t` only one result
could ever be used anyway.

When run directly (outside of qutebrowser), the selected bookmark is always
opened in a new tab, regardless of whether `-t` was passed, via `qutebrowser` launched
with any [`QUTEBROWSER_FLAGS`](#qutebrowser_flags)/[`QUTEBROWSER_ENV`](#qutebrowser_env)
you've configured.

```
:buku-browse
:buku-browse -t
```

#### Multi-select

With [`DMENU_MULTI_FLAG`](#dmenu_multi_flag) set, `buku-browse -t` lets you choose
multiple bookmarks at once and they will all be opened. The first selected bookmark
respects the `-t` flag; all subsequent ones always open in new tabs.

### `buku-retag`

```
:buku-retag [-n|--dry-run] [id|URL ...]
```

Apply your current [`add_additional_tags`](#add_additional_tags) rules to bookmarks you
already have -- e.g. after adding or changing a rule. With no arguments, every bookmark
is retagged; otherwise only the given bookmark indices and/or exact URLs (any that don't
match a bookmark are warned about and skipped).

The hook runs once per bookmark, exactly as it does when a bookmark is added, and
`buku-retag` only ever **adds** tags: removing a rule won't remove the tags it already
added. Each bookmark that gets new tags is listed, followed by a summary.

`-n`/`--dry-run` lists the tags that would be added without changing anything.

Errors out if `add_additional_tags` isn't defined.

```
:buku-retag
:buku-retag --dry-run
$ retag.sh 12 42 https://example.com
```

### `buku-random`

```
:buku-random [--domain|--title] [--all] [-t] [-n <N>] [-q|--quiet] [--dmenu-invocation <cmd>] [term, ...]
```

Pick one or more random bookmarks with buku's `--random`, optionally narrowing the pool
first. Only one kind of filter applies at a time:

- by default, **tags** (exact tag names, like buku's `--stag`)
- `--domain`: the URL (buku's `:` search marker)
- `--title`: the title (buku's `.` search marker)

Terms are comma-separated (their arguments are joined with spaces, then split on commas,
so multi-word terms need no quoting). A bookmark qualifies if it matches **any** of the
terms; pass `--all` to require **all** of them. With no terms, the pick is from every
bookmark.

`--domain` and `--title` use buku's ordinary keyword search, which is not a host check:
`--domain github.com` matches `github.com` anywhere in the URL, including the path or
query string.

`-n <N>` picks `N` distinct bookmarks (fewer if fewer match), and all of them are
opened. The first respects `-t` (open in a new tab); any later ones always open in new
tabs.

If no terms are given on the command line, and `-q`/`--quiet` isn't given, you're
prompted for them through the configured picker:

- tags: a picker over every tag in use (multi-select if
  [`DMENU_MULTI_FLAG`](#dmenu_multi_flag) is set); you can also type tags, comma-separated
- `--domain`/`--title`: a free-text prompt, comma-separated

If [`DMENU_MSG_FLAG`](#dmenu_msg_flag) is set, the prompt shows which filter and match
mode are in use. Leave the prompt empty to pick from every bookmark; cancel it to abort.

Like [`buku-browse`](#buku-browse), when run directly (outside of qutebrowser) it still
prompts, and every pick opens in a new tab, regardless of `-t`, via `qutebrowser`
launched with any [`QUTEBROWSER_FLAGS`](#qutebrowser_flags)/[`QUTEBROWSER_ENV`](#qutebrowser_env)
you've configured.

```
:buku-random
:buku-random -t -n 3
:buku-random --all music, live
:buku-random --domain youtube.com, vimeo.com
:buku-random --title how to
$ random.sh -n 5 recipes
```
