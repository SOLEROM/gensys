#!/usr/bin/env python3
"""export_bookmarks.py — Firefox bookmarks -> standard Netscape bookmarks.html.

Stdlib only, no pip installs required (must run unattended on a bare box).
Two input modes:

  --jsonlz4 <file>   decompress one of Firefox's own auto-backups
                      (<profile>/bookmarkbackups/bookmarks-*.jsonlz4) and
                      convert it. Safe to use even while Firefox is running,
                      since the backup file itself is a static snapshot.

  --sqlite  <file>   read a profile's places.sqlite directly (read-only).
                      Only works if that profile is NOT the one currently
                      locked open by a running Firefox instance.

Output is the universal Netscape "bookmarks.html" format every browser
(Firefox, Chrome, Edge, ...) can import via its own "Import Bookmarks from
HTML" action.
"""
import argparse
import html
import json
import sqlite3
import sys

MOZLZ4_MAGIC = b"mozLz40\0"


def lz4_block_decompress(data: bytes) -> bytes:
    """Minimal pure-Python LZ4 *block* format decoder (not the LZ4 frame
    format) — this is all mozlz4 needs, and keeps this script dependency-free."""
    out = bytearray()
    i, n = 0, len(data)
    while i < n:
        token = data[i]
        i += 1
        lit_len = token >> 4
        if lit_len == 15:
            while True:
                b = data[i]
                i += 1
                lit_len += b
                if b != 255:
                    break
        out += data[i : i + lit_len]
        i += lit_len
        if i >= n:
            break
        offset = data[i] | (data[i + 1] << 8)
        i += 2
        match_len = token & 0x0F
        if match_len == 15:
            while True:
                b = data[i]
                i += 1
                match_len += b
                if b != 255:
                    break
        match_len += 4
        start = len(out) - offset
        for k in range(match_len):
            out.append(out[start + k])
    return bytes(out)


def load_tree_from_jsonlz4(path: str) -> dict:
    with open(path, "rb") as f:
        raw = f.read()
    if raw[:8] != MOZLZ4_MAGIC:
        raise ValueError(f"{path}: not a mozlz4 file (bad magic)")
    payload = raw[12:]  # 8-byte magic + 4-byte little-endian decompressed size
    return json.loads(lz4_block_decompress(payload))


def load_tree_from_sqlite(path: str) -> dict:
    con = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
    con.row_factory = sqlite3.Row
    cur = con.cursor()

    def node(bookmark_id: int, title: str, guid: str) -> dict:
        row = cur.execute(
            "select id, type, title, fk from moz_bookmarks where id=?", (bookmark_id,)
        ).fetchone()
        children_rows = cur.execute(
            "select id, type, title, fk from moz_bookmarks where parent=? order by position",
            (bookmark_id,),
        ).fetchall()
        children = []
        for r in children_rows:
            if r["type"] == 2:  # folder
                children.append(node(r["id"], r["title"] or "", ""))
            elif r["type"] == 1:  # bookmark
                url_row = cur.execute(
                    "select url from moz_places where id=?", (r["fk"],)
                ).fetchone()
                children.append(
                    {
                        "type": "text/x-moz-place",
                        "title": r["title"] or "",
                        "uri": url_row["url"] if url_row else "",
                    }
                )
            elif r["type"] == 3:  # separator
                children.append({"type": "text/x-moz-place-separator"})
        return {"type": "text/x-moz-place-container", "title": title, "children": children}

    root_id_row = cur.execute(
        "select id from moz_bookmarks where guid='root________'"
    ).fetchone()
    root_id = root_id_row["id"] if root_id_row else 1
    tree = node(root_id, "", "root________")
    con.close()
    return tree


def node_to_html(node: dict, out: list, depth: int = 1) -> int:
    """Recursively emit Netscape-format HTML. Returns count of bookmarks emitted."""
    indent = "    " * depth
    count = 0
    ntype = node.get("type")
    if ntype == "text/x-moz-place":
        title = html.escape(node.get("title") or node.get("uri", ""))
        uri = html.escape(node.get("uri", ""), quote=True)
        date_added = int((node.get("dateAdded") or 0) / 1_000_000)
        out.append(f'{indent}<DT><A HREF="{uri}" ADD_DATE="{date_added}">{title}</A>')
        count = 1
    elif ntype == "text/x-moz-place-container":
        title = html.escape(node.get("title") or "(untitled folder)")
        children = node.get("children") or []
        if depth == 1:
            # synthetic root — just recurse into children at the same depth,
            # don't emit a folder heading for it.
            for child in children:
                count += node_to_html(child, out, depth)
        else:
            out.append(f"{indent}<DT><H3>{title}</H3>")
            out.append(f"{indent}<DL><p>")
            for child in children:
                count += node_to_html(child, out, depth + 1)
            out.append(f"{indent}</DL><p>")
    elif ntype == "text/x-moz-place-separator":
        out.append(f"{indent}<HR>")
    return count


def main() -> int:
    ap = argparse.ArgumentParser()
    src = ap.add_mutually_exclusive_group(required=True)
    src.add_argument("--jsonlz4", help="path to a bookmarks-*.jsonlz4 auto-backup")
    src.add_argument("--sqlite", help="path to a profile's places.sqlite (read-only)")
    ap.add_argument("-o", "--output", required=True, help="output bookmarks.html path")
    args = ap.parse_args()

    tree = (
        load_tree_from_jsonlz4(args.jsonlz4)
        if args.jsonlz4
        else load_tree_from_sqlite(args.sqlite)
    )

    body: list = []
    count = node_to_html(tree, body, depth=1)

    html_out = (
        "<!DOCTYPE NETSCAPE-Bookmark-file-1>\n"
        '<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=UTF-8">\n'
        "<TITLE>Bookmarks</TITLE>\n"
        "<H1>Bookmarks</H1>\n"
        "<DL><p>\n" + "\n".join(body) + "\n</DL><p>\n"
    )
    with open(args.output, "w", encoding="utf-8") as f:
        f.write(html_out)

    print(f"{count} bookmark(s) -> {args.output}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
