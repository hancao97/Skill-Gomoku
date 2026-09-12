"""Fetch only the macOS member from Godot's official multi-platform ZIP."""
from pathlib import Path
import binascii
import io
import os
import re
import struct
import subprocess
import tempfile
import zlib

URL = "https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz"
TARGET = Path.home() / "Library/Application Support/Godot/export_templates/4.7.2.stable"
PROXY = os.environ.get("RAINFALL_DOWNLOAD_PROXY")
work = Path(tempfile.mkdtemp(prefix="rainfall-template-"))

def request(byte_range):
    begin, requested_end = map(int, byte_range.split("-"))
    cursor = begin
    pieces = []
    output, headers = work / "range.bin", work / "headers.txt"
    for attempt in range(24):
        command = ["curl", "-fLsS", "--http1.1", "--retry", "2", "--max-time", "180", "--range", f"{cursor}-{requested_end}",
                   "-D", str(headers), "-o", str(output)]
        if PROXY:
            command += ["--proxy", PROXY]
        result = subprocess.run(command + [URL])
        if result.returncode not in (0, 18):
            result.check_returncode()
        info = headers.read_text()
        matches = re.findall(r"content-range:\s*bytes\s+(\d+)-(\d+)/(\d+)", info, re.I)
        if not matches:
            raise RuntimeError("The official mirror did not honor HTTP Range")
        returned_start, returned_end, total = map(int, matches[-1])
        data = output.read_bytes()
        if returned_start != cursor or not data or len(data) > requested_end-cursor+1:
            raise RuntimeError("Unexpected byte range")
        pieces.append(data)
        cursor += len(data)
        if cursor == requested_end+1:
            return b"".join(pieces), begin, total
        print("Resuming partial official transfer:", cursor-begin, "bytes", flush=True)
    raise RuntimeError("Too many interrupted transfers")

tail, tail_offset, total = request("1281284145-1281349701")
eocd = tail.rfind(b"PK\x05\x06")
if eocd < 0:
    raise RuntimeError("ZIP directory not found")
_, disk, directory_disk, disk_entries, entries, size, offset, comment = struct.unpack_from("<4s4H2IH", tail, eocd)
if disk or directory_disk:
    raise RuntimeError("Multi-disk archive unsupported")
directory = tail[offset-tail_offset:offset-tail_offset+size] if offset >= tail_offset else request(f"{offset}-{offset+size-1}")[0]
members = []
position = 0
while position < len(directory):
    fields = struct.unpack_from("<4s6H3I5H2I", directory, position)
    if fields[0] != b"PK\x01\x02":
        raise RuntimeError("Invalid central directory")
    method, crc, compressed, uncompressed = fields[4], fields[7], fields[8], fields[9]
    name_len, extra_len, comment_len, local_offset = fields[10], fields[11], fields[12], fields[16]
    name = directory[position+46:position+46+name_len].decode()
    if name.endswith("/macos.zip") or name.endswith("/version.txt"):
        members.append((name, method, crc, compressed, uncompressed, local_offset))
    position += 46 + name_len + extra_len + comment_len
print("Official template members:", [(m[0], m[3]) for m in members], flush=True)
if not any(m[0].endswith("/macos.zip") for m in members):
    raise RuntimeError("No macOS template in release")
TARGET.mkdir(parents=True, exist_ok=True)
for name, method, crc, compressed, uncompressed, local_offset in members:
    destination = TARGET / Path(name).name
    if destination.exists():
        existing = destination.read_bytes()
        if len(existing) == uncompressed and binascii.crc32(existing) & 0xffffffff == crc:
            print("Verified existing template:", destination, flush=True)
            continue
    header = request(f"{local_offset}-{local_offset+1023}")[0]
    if header[:4] != b"PK\x03\x04":
        raise RuntimeError("Invalid ZIP member")
    name_len, extra_len = struct.unpack_from("<HH", header, 26)
    start = local_offset + 30 + name_len + extra_len
    payload = request(f"{start}-{start+compressed-1}")[0]
    data = zlib.decompress(payload, -15) if method == 8 else payload
    if len(data) != uncompressed or binascii.crc32(data) & 0xffffffff != crc:
        raise RuntimeError("Template CRC/size mismatch")
    destination = TARGET / Path(name).name
    destination.write_bytes(data)
    print("Verified and installed:", destination, len(data), flush=True)
for file in work.iterdir():
    file.unlink()
work.rmdir()
