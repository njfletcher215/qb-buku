#!/usr/bin/env python3

import sys
import buku


def main():
    if len(sys.argv) != 2:
        print(f'Usage: {sys.argv[0]} URL', file=sys.stderr)
        sys.exit(1)

    url = sys.argv[1]
    db = buku.BukuDb(chatty=False)
    row = db.conn.execute('SELECT id FROM bookmarks WHERE URL=?', (url,)).fetchone()

    if row is None:
        print(f'No bookmark found with URL: {url}', file=sys.stderr)
        db.close()
        sys.exit(1)

    db.close()

    return(row[0])


if __name__ == '__main__':
    print(main())
