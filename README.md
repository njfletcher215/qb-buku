# qb-buku

qutebrowser userscripts for managing [buku](https://github.com/jarun/buku) bookmarks.

## Scripts

| Script | Description |
|---|---|
| `add.sh` | Bookmark the current page (or a given URL) |
| `delete.sh` | Delete one or more bookmarks by index, range, or URL |
| `update.sh` | Update a bookmark's URL, title, or tags (or interactively via a dmenu picker) |
| `browse.sh` | Browse and open bookmarks via a dmenu-style picker |

## Dependencies

- [buku](https://github.com/jarun/buku) — installed system-wide via your package manager
- [jq](https://jqlang.org) — used by `browse.sh`
- Python 3 with the `buku` module importable — used by `delete.sh` and `update.sh` to resolve URLs to bookmark IDs; `install.sh` sets up a venv for this automatically
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
   ln -s "$src/add.sh"    "$userscripts/buku-add"
   ln -s "$src/delete.sh" "$userscripts/buku-delete"
   ln -s "$src/update.sh" "$userscripts/buku-update"
   ln -s "$src/browse.sh" "$userscripts/buku-browse"
   ```

5. Add the following to your `~/.config/qutebrowser/config.py`:

   ```python
   # qb-buku aliases
   c.aliases.update({
       'buku-add':    'spawn --userscript buku-add',
       'buku-delete': 'spawn --userscript buku-delete',
       'buku-update': 'spawn --userscript buku-update',
       'buku-browse': 'spawn --userscript buku-browse',
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

Can be overridden per-invocation with `buku-browse`'s, `buku-delete`'s, or
`buku-update`'s `--dmenu-invocation <cmd>` flag.

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
`buku-delete -d`'s bookmark picker, and the tag-selection steps of interactive
`buku-add` and `buku-update -d`. Different pickers expose this differently:

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

### `QUTEBROWSER_FLAGS`

Extra flags passed to `qutebrowser` when `buku-browse` launches it directly (i.e. when
run outside of a running qutebrowser instance). Empty by default.

```bash
QUTEBROWSER_FLAGS=(--backend webengine)
```

### `QUTEBROWSER_ENV`

Extra environment variables set for `qutebrowser` when `buku-browse` launches it
directly (i.e. when run outside of a running qutebrowser instance). Empty by default.

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
