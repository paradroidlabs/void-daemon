"""Fetch only the Windows x64 release member of Godot's official template ZIP.

Uses HTTP ranges rather than downloading 1.2 GB of unrelated platforms. The
download is HTTPS-only, range lengths are checked, and ZIP size/CRC are verified.
The extracted engine is not executed here. Requires only Python's standard library.
"""

import argparse
import io
import json
import struct
import urllib.request
import zipfile
import zlib
from pathlib import Path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", default="4.7.1-stable")
    args = parser.parse_args()
    if not all(c.isalnum() or c in ".-" for c in args.version):
        parser.error("Invalid version")
    url = (
        "https://github.com/godotengine/godot-builds/releases/download/"
        f"{args.version}/Godot_v{args.version}_export_templates.tpz"
    )

    def read_range(start, end=None):
        value = f"bytes={start}-{end}" if end is not None else f"bytes={start}"
        req = urllib.request.Request(url, headers={"Range": value, "User-Agent": "VOID-DAEMON-build"})
        with urllib.request.urlopen(req, timeout=90) as response:
            if response.status != 206:
                raise RuntimeError("Server did not honor the range; refusing full archive download")
            raw = response.read()
            declared = response.headers.get("Content-Range", "")
            if not declared.startswith("bytes "):
                raise RuntimeError("Missing Content-Range")
            span, total = declared[6:].split("/")
            first, last = map(int, span.split("-"))
            if len(raw) != last - first + 1:
                raise RuntimeError("Incomplete download range")
            if end is not None and (first != start or last != end):
                raise RuntimeError("Unexpected response range")
            return raw, int(total)

    metadata_req = urllib.request.Request(
        f"https://api.github.com/repos/godotengine/godot-builds/releases/tags/{args.version}",
        headers={"User-Agent": "VOID-DAEMON-build"},
    )
    with urllib.request.urlopen(metadata_req, timeout=30) as response:
        metadata = json.load(response)
    asset = next(x for x in metadata["assets"] if x["browser_download_url"] == url)
    total = int(asset["size"])
    tail, _ = read_range(total - 65558, total - 1)
    eocd = tail.rfind(b"PK\x05\x06")
    if eocd < 0:
        raise RuntimeError("ZIP directory trailer not found")
    _, disk, cd_disk, _, entries, cd_size, cd_offset, comment = struct.unpack_from("<4s4H2LH", tail, eocd)
    if disk or cd_disk or cd_offset == 0xFFFFFFFF or cd_size == 0xFFFFFFFF:
        raise RuntimeError("Multi-disk / ZIP64 archive unsupported")
    if eocd + 22 + comment != len(tail):
        raise RuntimeError("Unexpected ZIP trailer")
    directory, _ = read_range(cd_offset, cd_offset + cd_size - 1)
    # Build a metadata-only ZIP with its central directory rebased to zero.
    trailer = struct.pack("<4s4H2LH", b"PK\x05\x06", 0, 0, entries, entries, cd_size, 0, 0)
    with zipfile.ZipFile(io.BytesIO(directory + trailer)) as archive:
        candidates = [x for x in archive.infolist() if x.filename.endswith("/windows_release_x86_64.exe")]
        if len(candidates) != 1:
            raise RuntimeError(f"Expected one Windows template; found {[x.filename for x in archive.infolist() if 'windows' in x.filename]}")
        item = candidates[0]
    header, _ = read_range(item.header_offset, item.header_offset + 29)
    if header[:4] != b"PK\x03\x04":
        raise RuntimeError("Invalid ZIP local header")
    name_len, extra_len = struct.unpack_from("<HH", header, 26)
    payload_offset = item.header_offset + 30 + name_len + extra_len
    compressed, _ = read_range(payload_offset, payload_offset + item.compress_size - 1)
    if item.compress_type == zipfile.ZIP_DEFLATED:
        payload = zlib.decompress(compressed, -15)
    elif item.compress_type == zipfile.ZIP_STORED:
        payload = compressed
    else:
        raise RuntimeError("Unsupported ZIP compression")
    if len(payload) != item.file_size or zlib.crc32(payload) & 0xFFFFFFFF != item.CRC:
        raise RuntimeError("ZIP member size/CRC verification failed")
    destination = Path(__file__).resolve().parents[1] / ".tools" / "windows" / "windows_release_x86_64.exe"
    if destination.exists():
        raise RuntimeError(f"Already exists: {destination}; preserve it rather than overwrite")
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(payload)
    print(f"WINDOWS_TEMPLATE_OK {destination} bytes={len(payload)} downloaded={len(tail)+len(directory)+len(header)+len(compressed)} archive_bytes={total}")


if __name__ == "__main__":
    main()
