#!/usr/bin/env python3
"""Convert Intel HEX file to a flat binary image.

The output image spans from the lowest to highest address present in the HEX
records and fills gaps with 0x00.
"""

from __future__ import annotations

import argparse
from pathlib import Path


def parse_hex_line(line: str) -> tuple[int, int, int, bytes]:
    line = line.strip()
    if not line:
        raise ValueError("empty line")
    if not line.startswith(":"):
        raise ValueError(f"invalid record start: {line!r}")

    raw = bytes.fromhex(line[1:])
    if len(raw) < 5:
        raise ValueError(f"record too short: {line!r}")

    count = raw[0]
    addr = (raw[1] << 8) | raw[2]
    rectype = raw[3]
    data = raw[4 : 4 + count]
    checksum = raw[4 + count]

    total = sum(raw[:-1]) & 0xFF
    calc = ((~total + 1) & 0xFF)
    if calc != checksum:
        raise ValueError(f"checksum mismatch in line: {line!r}")

    return count, addr, rectype, data


def convert_file(inp: Path, out: Path, base: int | None = None, size: int | None = None) -> None:
    memory: dict[int, int] = {}
    upper = 0

    with inp.open("r", encoding="ascii") as f:
        for lineno, line in enumerate(f, start=1):
            line = line.strip()
            if not line:
                continue
            try:
                count, addr, rectype, data = parse_hex_line(line)
            except Exception as exc:
                raise ValueError(f"{inp}:{lineno}: {exc}") from exc

            if rectype == 0x00:  # data
                addr_base = upper + addr
                for i, b in enumerate(data):
                    memory[addr_base + i] = b
            elif rectype == 0x01:  # EOF
                break
            elif rectype == 0x02:  # extended segment address
                if count != 2:
                    raise ValueError(f"{inp}:{lineno}: invalid type 02 length")
                upper = (((data[0] << 8) | data[1]) << 4)
            elif rectype == 0x04:  # extended linear address
                if count != 2:
                    raise ValueError(f"{inp}:{lineno}: invalid type 04 length")
                upper = (((data[0] << 8) | data[1]) << 16)
            elif rectype in (0x03, 0x05):
                # Start address records are not needed for flat ROM images.
                continue
            else:
                raise ValueError(f"{inp}:{lineno}: unsupported record type {rectype:#x}")

    if not memory:
        raise ValueError(f"{inp}: no data records found")

    lo = min(memory)
    hi = max(memory)

    if base is None:
        base = lo
    if size is None:
        size = (hi - base) + 1

    if size <= 0:
        raise ValueError("output size must be positive")

    end = base + size - 1
    if lo < base or hi > end:
        raise ValueError(
            f"data range {lo:#x}-{hi:#x} outside requested output range {base:#x}-{end:#x}"
        )

    image = bytearray(size)
    for addr, val in memory.items():
        image[addr - base] = val

    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_bytes(image)


def main() -> None:
    parser = argparse.ArgumentParser(description="Convert Intel HEX to flat binary")
    parser.add_argument("--base", type=lambda x: int(x, 0), default=None, help="Base address for output image")
    parser.add_argument("--size", type=lambda x: int(x, 0), default=None, help="Output image size in bytes")
    parser.add_argument("input", type=Path, help="Input Intel HEX file")
    parser.add_argument("output", type=Path, help="Output binary file")
    args = parser.parse_args()
    convert_file(args.input, args.output, base=args.base, size=args.size)


if __name__ == "__main__":
    main()
