#!/usr/bin/env python3
"""Check the Er-Con rebrand kit. No domain controller required.

    python3 scripts/check-kit.py
    python3 scripts/check-kit.py --write-manifest
"""

from __future__ import annotations

import hashlib
import json
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PAYLOAD = ROOT / "payload"
FONTS_DIR = PAYLOAD / "Assets" / "Fonts to install"
MANIFEST = PAYLOAD / "fonts.manifest.json"

REQUIRED = [
    PAYLOAD / "Install-ErConFonts.ps1",
    PAYLOAD / "Copy-ErConAssets.ps1",
    PAYLOAD / "Verify-ErConRebrand.ps1",
    PAYLOAD / "Remove-ErConFonts.ps1",
    PAYLOAD / "Assets" / "READ ME FIRST.md",
    PAYLOAD / "Assets" / "Er-Con Brand Standards.pdf",
    PAYLOAD / "Assets" / "Templates" / "Er-Con Template.potx",
    PAYLOAD / "Assets" / "Templates" / "Er-Con Letterhead.dotx",
    PAYLOAD / "Assets" / "Logos" / "ErCon-Logo-Navy.svg",
    PAYLOAD / "Assets" / "Office Theme" / "Er-Con Theme Colors.xml",
    ROOT / "Deploy-ErConRebrandGpo.ps1",
    ROOT / "New-ErConAssetShare.ps1",
    ROOT / "Unlink-ErConRebrandGpo.ps1",
    ROOT / "ADMIN-INSTALLATION.md",
    ROOT / "README.md",
    ROOT / "AGENTS.md",
]


def fail(message: str) -> None:
    print(f"FAIL {message}", file=sys.stderr)


def name_id_4(path: Path) -> str:
    data = path.read_bytes()
    num = struct.unpack(">H", data[4:6])[0]
    name_off = name_len = None
    for i in range(num):
        rec = data[12 + i * 16 : 12 + (i + 1) * 16]
        tag, _chk, off, length = struct.unpack(">4sIII", rec)
        if tag == b"name":
            name_off, name_len = off, length
            break
    if name_off is None:
        raise SystemExit(f"no name table in {path}")
    table = data[name_off : name_off + name_len]
    _fmt, count, string_offset = struct.unpack(">HHH", table[:6])
    for i in range(count):
        rec = table[6 + i * 12 : 6 + (i + 1) * 12]
        plat, enc, lang, name_id, length, offset = struct.unpack(">HHHHHH", rec)
        if plat == 3 and enc == 1 and lang == 0x409 and name_id == 4:
            raw = table[string_offset + offset : string_offset + offset + length]
            return raw.decode("utf-16-be")
    raise SystemExit(f"no English full name in {path}")


def has_fvar(path: Path) -> bool:
    data = path.read_bytes()
    num = struct.unpack(">H", data[4:6])[0]
    for i in range(num):
        tag = data[12 + i * 16 : 16 + i * 16]
        if tag == b"fvar":
            return True
    return False


def font_records() -> list[dict]:
    records = []
    for path in sorted(FONTS_DIR.rglob("*.ttf")):
        full = name_id_4(path)
        family = full
        for suffix in (" Bold Italic", " Bold", " Italic", " Regular"):
            if full.endswith(suffix):
                family = full[: -len(suffix)]
                break
        records.append(
            {
                "file": path.name,
                "relativePath": path.relative_to(PAYLOAD).as_posix(),
                "family": family,
                "fullName": full,
                "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                "variable": has_fvar(path),
            }
        )
    return records


def write_manifest(records: list[dict]) -> None:
    body = {
        "version": "2026.10.19",
        "fonts": [
            {key: item[key] for key in ("file", "relativePath", "family", "fullName", "sha256")}
            for item in records
        ],
    }
    MANIFEST.write_text(json.dumps(body, indent=2) + "\n")
    print(f"wrote {MANIFEST}")


def main() -> int:
    errors = 0
    records = font_records()
    if "--write-manifest" in sys.argv:
        write_manifest(records)

    if len(records) != 12:
        fail(f"expected 12 ttf files, found {len(records)}")
        errors += 1
    for item in records:
        if item["variable"]:
            fail(f"variable font (fvar table): {item['relativePath']}")
            errors += 1
        if "SemiBold" in item["fullName"] or "SemiBold" in item["file"]:
            fail(f"SemiBold is not part of this kit: {item['file']}")
            errors += 1

    for path in REQUIRED:
        if not path.exists():
            fail(f"missing {path.relative_to(ROOT)}")
            errors += 1

    if MANIFEST.exists():
        manifest = json.loads(MANIFEST.read_text())
        listed = {item["relativePath"]: item for item in manifest.get("fonts", [])}
        if len(listed) != 12:
            fail(f"manifest lists {len(listed)} fonts, expected 12")
            errors += 1
        for item in records:
            row = listed.get(item["relativePath"])
            if row is None:
                fail(f"manifest missing {item['relativePath']}")
                errors += 1
                continue
            if row.get("sha256", "").lower() != item["sha256"]:
                fail(f"hash mismatch {item['file']}")
                errors += 1
            if row.get("fullName") != item["fullName"]:
                fail(f"full name mismatch {item['file']}: manifest {row.get('fullName')!r} file {item['fullName']!r}")
                errors += 1
    else:
        fail("payload/fonts.manifest.json is missing. Run with --write-manifest")
        errors += 1

    deploy = (ROOT / "Deploy-ErConRebrandGpo.ps1").read_text(encoding="utf-8")
    for needle in ("ConfirmDomainWide", "er-contech", "Er-Con Rebrand - Fonts and Assets", "Authenticated Users"):
        if needle not in deploy:
            fail(f"Deploy-ErConRebrandGpo.ps1 no longer contains {needle!r}")
            errors += 1
    copy = (PAYLOAD / "Copy-ErConAssets.ps1").read_text(encoding="utf-8")
    for needle in ("Documents", "Fonts to install", "USERPROFILE"):
        if needle not in copy:
            fail(f"Copy-ErConAssets.ps1 no longer contains {needle!r}")
            errors += 1
    share = (ROOT / "New-ErConAssetShare.ps1").read_text(encoding="utf-8")
    for needle in ("D:\\Er-Con Rebrand Assets", "S-1-5-11", "inheritance:r"):
        if needle not in share:
            fail(f"New-ErConAssetShare.ps1 no longer contains {needle!r}")
            errors += 1

    if errors:
        print(f"{errors} check(s) failed")
        return 1
    print("ok 12 fonts, manifest matches, required files present")
    return 0


if __name__ == "__main__":
    sys.exit(main())
