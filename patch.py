#!/usr/bin/env python3
"""Hades II 4:3 UI patcher (nova43).

Appends patch/nova43.lua to the game's Content/Scripts/RoomLogic.lua, which the engine loads at boot.
Only known vanilla RoomLogic.lua files are accepted, and the patch is verified by stripping it back
off and comparing against the vanilla hash, so restore is exact.

  python3 patch.py patch   <RoomLogic.lua | Scripts dir | Content dir | game dir> [--out FILE]
  python3 patch.py restore <same>
  python3 patch.py status  <same>

Exit codes: 0 ok, 1 error/verify failed, 2 usage, 3 already patched, 4 unknown build, 5 not patched.
"""
import hashlib
import os
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))
BLOCK_PATH = os.path.join(ROOT, "patch", "nova43.lua")

PATCH_VERSION = 1
# sha256 of vanilla Content/Scripts/RoomLogic.lua -> Steam build
KNOWN_VANILLA = {
    "affb8ee3dc2806e1b9a1a5f8f8c3616f9d2010f267e58f175095f5c16e072d5b": "25481925",
}
# files the Lua block hooks into; it checks them itself at runtime, these are informational
HOOKED_SCRIPTS = {
    "UpgradeChoiceLogic.lua": "07e7a81d5674ecd1d774cec81b4450b6e16f2a9dd315996d786ef71518f95292",
    "UpgradeChoiceData.lua": "2ef90d95e9051d21968675f064e1d5fe6291dffd4cae7d77eb699a5a2a118aee",
    "NarrativeLogic.lua": "fca2790a6104fb2f28e625fe4c8bb0dfb2cdeb4d5f93cf82842019c6d184f02c",
    "NarrativeData.lua": "94494ed7a04a2a22af26621dab8cd17dceb78c401215f24f1db236ffc8ebe29b",
    "UILogic.lua": "6c01d52bc94c6018e392b0e40ce758c013b2788af805daba2552ad28b7174277",
}

BEGIN = b"\r\n\r\n-- >>> nova43 "
END = b"-- <<< nova43 <<<\r\n"


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def block_bytes():
    with open(BLOCK_PATH, "rb") as f:
        text = f.read().replace(b"\r\n", b"\n")
    body = text.replace(b"\n", b"\r\n")
    header = BEGIN + b"v%d: Hades II 4:3 UI patch. Remove with `patch.py restore` or Steam Verify Files. >>>\r\n" % PATCH_VERSION
    return header + body + END


def is_patched(data):
    return BEGIN in data


def strip(data):
    """Patched RoomLogic.lua -> the original bytes, or None if the block is malformed."""
    i = data.find(BEGIN)
    if i < 0 or data.count(BEGIN) != 1 or not data.endswith(END):
        return None
    return data[:i]


def patch_bytes(data):
    """Returns (reason, output). reason is 'ok', 'already_patched' or 'unknown_build'."""
    if is_patched(data):
        return "already_patched", None
    if sha256(data) not in KNOWN_VANILLA:
        return "unknown_build", None
    out = data + block_bytes()
    failures = verify(out)
    if failures:
        raise RuntimeError("verification failed: " + "; ".join(failures))
    return "ok", out


def verify(out):
    failures = []
    if out.count(BEGIN) != 1:
        failures.append("begin marker must appear exactly once")
    if not out.endswith(END):
        failures.append("end marker must close the file")
    orig = strip(out)
    if orig is None or sha256(orig) not in KNOWN_VANILLA:
        failures.append("stripping the block does not give a known vanilla RoomLogic.lua")
    elif out != orig + block_bytes():
        failures.append("appended block differs from patch/nova43.lua")
    return failures


def resolve(path):
    """Accepts RoomLogic.lua itself, Content/Scripts, Content, or the game dir (Windows or macOS layout)."""
    if os.path.isfile(path):
        return path
    for rel in ("RoomLogic.lua",
                os.path.join("Scripts", "RoomLogic.lua"),
                os.path.join("Content", "Scripts", "RoomLogic.lua"),
                os.path.join("Hades II.app", "Contents", "Resources", "Content", "Scripts", "RoomLogic.lua")):
        p = os.path.join(path, rel)
        if os.path.isfile(p):
            return p
    return None


def report_hooked(scripts_dir):
    for name, want in HOOKED_SCRIPTS.items():
        p = os.path.join(scripts_dir, name)
        if not os.path.isfile(p):
            continue
        with open(p, "rb") as f:
            got = sha256(f.read())
        if got != want:
            print(f"  note: {name} differs from build 25481925; the patch will check itself in game and stay off if the layout changed")


def write_atomic(path, data):
    tmp = path + ".nova43.tmp"
    with open(tmp, "wb") as f:
        f.write(data)
    os.replace(tmp, path)


def main(argv):
    if len(argv) < 3 or argv[1] not in ("patch", "restore", "status"):
        print(__doc__.strip())
        return 2
    cmd, target = argv[1], argv[2]
    out_path = None
    if "--out" in argv:
        out_path = argv[argv.index("--out") + 1]
    path = resolve(target)
    if path is None:
        print(f"RoomLogic.lua not found under {target}")
        return 1
    with open(path, "rb") as f:
        data = f.read()
    print(f"{path}\n  sha256 {sha256(data)}")
    report_hooked(os.path.dirname(path))

    if cmd == "status":
        if is_patched(data):
            orig = strip(data)
            ok = orig is not None and sha256(orig) in KNOWN_VANILLA
            print(f"  patched (nova43), restorable to vanilla: {'yes' if ok else 'NO'}")
        elif sha256(data) in KNOWN_VANILLA:
            print(f"  vanilla, build {KNOWN_VANILLA[sha256(data)]}")
        else:
            print("  unknown RoomLogic.lua (different game build, or edited by another mod)")
        return 0

    if cmd == "restore":
        if not is_patched(data):
            print("  not patched")
            return 5
        orig = strip(data)
        if orig is None or sha256(orig) not in KNOWN_VANILLA:
            print("  the patch block is damaged; use Steam > Properties > Installed Files > Verify integrity")
            return 1
        write_atomic(out_path or path, orig)
        print(f"  restored vanilla, sha256 {sha256(orig)}")
        return 0

    reason, out = patch_bytes(data)
    if reason == "already_patched":
        print("  already patched")
        return 3
    if reason == "unknown_build":
        print("  unknown RoomLogic.lua: this patcher supports Steam build " + ", ".join(sorted(set(KNOWN_VANILLA.values()))))
        return 4
    if out_path:
        write_atomic(out_path, out)
    else:
        bak = path + ".bak"
        if not os.path.exists(bak):
            with open(bak, "wb") as f:
                f.write(data)
        write_atomic(path, out)
    print(f"  patched, verified; output sha256 {sha256(out)}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
