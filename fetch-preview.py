#!/usr/bin/env python3

import sys
import buku


def main():
    if len(sys.argv) != 2:
        print(f'Usage: {sys.argv[0]} URL', file=sys.stderr)
        sys.exit(1)

    url = sys.argv[1]
    result = buku.fetch_data(url)
    print(result.title)
    print(result.tags())


if __name__ == '__main__':
    main()
