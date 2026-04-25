# qb-buku

qutebrowser userscripts for managing [buku](https://github.com/jarun/buku) bookmarks.

## Scripts

| Script | Description |
|---|---|
| `add.sh` | Bookmark the current page (or a given URL) |
| `delete.sh` | Delete one or more bookmarks by index, range, or URL |
| `update.sh` | Update a bookmark's URL, title, or tags |
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

3. Edit `config.sh` and set `PYTHON` to the venv interpreter:

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

Edit `config.sh` in the repository directory.

### `DMENU_CMD`

The picker command, as a bash array. It must read lines from stdin and print selected
lines to stdout, one per line.

```bash
# rofi with multi-select (default)
DMENU_CMD=(rofi -dmenu -multi-select -i -p "bookmark")

# fuzzel
DMENU_CMD=(fuzzel --dmenu -p "bookmark")

# dmenu
DMENU_CMD=(dmenu -i -p "bookmark")
```

### `AUTO_FETCH_TAGS`

When `true`, `buku-add` automatically passes `+` to buku when tags are provided, so
buku fetches tags from the page itself and merges them with any tags you supply. Has no
effect when `+` or `-` is already given explicitly.

```bash
AUTO_FETCH_TAGS=true   # fetch and merge tags automatically
AUTO_FETCH_TAGS=false  # only use explicitly provided tags
```

### `PYTHON`

Path to the Python interpreter that has the `buku` module installed. Set automatically
by `install.sh`.

```bash
PYTHON=/home/you/.local/share/qb-buku/venv/bin/python3
```

## Usage

### `buku-add`

```
:buku-add [+|-] [tag, ...]
```

Bookmark the current page. When invoked with no arguments, uses the current page's URL.
When invoked with arguments, the first argument is the page's URL,
and the remaining arguments are a comma-separated list of tags.
The '+' modifier first fetches any tags from the page itself, then appends any user-specified tags.
The '-' modifier does the same, but removes any user-specified tags from the fetched set instead.

```
:buku-add
:buku-add + python, tools
:buku-add - python, tools
```

### `buku-delete`

```
:buku-delete [(index|N-M|URL) ...]
```

Delete a bookmark. With no arguments, deletes the bookmark for the current page.
Accepts buku indices, an `N-M` range, or exact URLs.

```
:buku-delete
:buku-delete 42
:buku-delete 10-20
:buku-delete https://example.com
```

### `buku-update`

```
:buku-update <index|URL> url <new-url>
:buku-update <index|URL> title <new-title>
:buku-update <index|URL> tags [+|-] <tag, ...>
```

Update a specific field of a bookmark, identified by index or exact URL.

```
:buku-update 7 title My Revised Title
:buku-update 7 url https://new-url.com
:buku-update 7 tags + newtag
:buku-update https://example.com tags - oldtag
```

### `buku-browse`

```
:buku-browse [-t]
```

Open the picker populated with all bookmarks. Pass `-t` to open the first selection in
a new tab (all subsequent selections always open in new tabs regardless).

```
:buku-browse
:buku-browse -t
```

#### Multi-select

When using a picker that supports multi-select, you can choose multiple bookmarks at
once and they will all be opened. [rofi](https://github.com/davatorium/rofi) supports
this natively via the `-multi-select` flag. [dmenu](https://tools.suckless.org/dmenu/)
supports it when built with the
[multi-select patch](https://tools.suckless.org/dmenu/patches/multi-select/).

The first selected bookmark respects the `-t` flag; all subsequent ones always open in
new tabs.
