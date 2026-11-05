#!/usr/bin/env python3
"""Verify the built JDCloud factory/sysupgrade images (jdcloud-ipq6018-nss).

Checks, for one device profile:
  * factory.bin exists, is non-empty, and starts with the FIT magic
    (0xd00dfeed) — the ipq60xx EmmcImage factory image is a FIT image
    (kernel + rootfs + metadata).
  * sysupgrade.bin exists and is non-empty (tar-based sysupgrade image).
  * both files are at least 1 MiB (a truncated build is far smaller).

This is a structural check only: it does not boot the image and does
not verify the DTB inside the FIT. It replaces the CR880x project's
verify-factory-ubi.py (UBI-specific; this device uses eMMC + FIT).

Usage: verify-factory-bin.py <factory.bin> <sysupgrade.bin>
Exits 0 on pass, 1 on any failure, printing the exact failing check.
"""
import os
import struct
import sys

FIT_MAGIC = 0xD00DFEED
MIN_SIZE = 1 * 1024 * 1024


def fail(msg):
    print(f"::error::{msg}")
    return 1


def main(factory, sysupgrade):
    status = 0
    for path in (factory, sysupgrade):
        if not os.path.isfile(path):
            status = fail(f"IMAGE MISSING: {path}")
            continue
        size = os.path.getsize(path)
        print(f"{path}: {size} bytes")
        if size < MIN_SIZE:
            status = fail(f"IMAGE TOO SMALL (<1 MiB, truncated?): {path} ({size} bytes)")
    if status:
        return status
    with open(factory, "rb") as f:
        magic = struct.unpack(">I", f.read(4))[0]
    if magic != FIT_MAGIC:
        return fail(
            f"FACTORY IMAGE IS NOT A FIT IMAGE: {factory} "
            f"(magic 0x{magic:08x}, expected 0xd00dfeed)"
        )
    print(f"factory.bin FIT magic OK (0xd00dfeed)")
    print("=== FACTORY IMAGE OK ===")
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("usage: verify-factory-bin.py <factory.bin> <sysupgrade.bin>")
        sys.exit(1)
    sys.exit(main(sys.argv[1], sys.argv[2]))
