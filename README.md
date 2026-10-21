# Hades II 4:3 UI Patch

Makes the boon-selection and dialogue screens of **Hades II** readable on 4:3 displays such as the **Retroid Pocket Nova** (4.5", 1280x960). Hades II already runs natively at 4:3. These two screens are the exception: they are 16:9 layouts drawn in a band in the middle of the screen, so their text is tiny. The patch is one Lua block appended to `Content/Scripts/RoomLogic.lua`. It zooms those two screens to fill the display. Nothing else in the game changes.

The patcher ships only our own Lua block and modifies your own copy of the game. **No game code is redistributed.**

> Unofficial fan project, not affiliated with or endorsed by Supergiant Games. Hades II and its files belong to them. The code here is MIT licensed ([LICENSE](LICENSE)).

## Install (players)

You patch your own copy of `RoomLogic.lua`. Nothing from the game is shipped here.

- **Web patcher** (any browser, including your phone): <https://jevonlipsey.github.io/hades2-43aspect/>. Drop in `RoomLogic.lua`, download the patched file, put it back. It runs in your browser and the file is not uploaded.
- **Desktop**: `python3 patch.py patch "/path/to/Hades II"` (Python 3.8+, standard library only). It verifies the result, saves the original as `RoomLogic.lua.bak` and installs the patched file.
- **Undo**: `python3 patch.py restore "/path/to/Hades II"`, copy `RoomLogic.lua.bak` back, or use Steam's **Verify integrity of game files**.

Step-by-step instructions, per-platform paths, Android handheld notes, display settings and troubleshooting are in **[docs/INSTALL.md](docs/INSTALL.md)**.

## Why the menus look small at 4:3

At 4:3 the game keeps a 1920-wide virtual canvas and makes it 1440 tall (`ScreenScaleY` is 1.333). Gameplay uses all of it. The boon-selection and dialogue screens are 1920x1080 layouts. They are drawn in a centred band, with frame art above and below to fill the rest.

On a 1280x960 handheld that band is a 1280x720 strip. Text in it is about 13 to 16 px tall.

## What the patch changes

Only `Content/Scripts/RoomLogic.lua` is modified. Every other game file is left as it is.

- **One block, appended.** The engine loads `RoomLogic.lua` at boot, and it imports all the other scripts first, so the block runs after them. It sits between `-- >>> nova43` and `-- <<< nova43 <<<` markers. This is the same injection point ModImporter uses.
- **A few engine calls are wrapped:** `CreateScreenObstacle`, `CreateTextBox`, `Attach`, `Teleport`, `SetScale`, `CreateAnimation`, `SetInteractProperty` and `AltAspectRatioFramesShow`.
- **They are rewritten only inside the two screens.** A call is changed only while one of the layout functions (`CreateUpgradeChoiceButton`, `TraitLockedPresentation`, `CreateScreenFromData` called from `OpenUpgradeChoiceMenu`, `DisplayTextLine`) is on the calling coroutine's stack.
- **Each screen is zoomed uniformly** by `ScreenScaleY` (1.333 at 4:3, 1.111 at 16:10) so it fills the screen. It is a crop of the 16:9 scene, never a stretch.
- **Text is re-rendered at the larger size.** Boon descriptions go from 19.5 to 26, dialogue from 24 to 32 (game units).
- **Boon screen:** the zoom pivot is left of centre so Mel stays mostly in frame. The title and header stay centred. The action bar (Boon Info / Choose) moves into the bottom band at its normal size. The keyword tooltips keep their vanilla position, because the engine draws them at a fixed size.
- **Letterbox frame art** is skipped on these two screens only.
- **At 16:9 nothing changes.** The block does not walk the stack at all.
- **Safe by default.** At load the block checks sentinel values in the game's data. If the scripts do not match the expected layout, it disables itself and the game runs vanilla.

## What gets cropped

A zoom that fills the screen has to cut something off.

- **Dialogue:** 12.5% of the scene width on each side, which is the outer edge of the character portrait.
- **Boon selection:** about 95 px on the left (part of Mel's hair and face) and 225 px on the right (decorative slot ends), measured on the 1280x720 band.

## Usage

```
python3 patch.py status  <target>
python3 patch.py patch   <target> [--out FILE]
python3 patch.py restore <target> [--out FILE]
```

`<target>` is `RoomLogic.lua`, the `Scripts` directory, the `Content` directory or the game directory.

- `status` reports whether the file is vanilla, patched or unknown. It changes nothing.
- `patch` appends the block, verifies the result, writes `RoomLogic.lua.bak` once (an existing backup is never overwritten) and installs. With `--out FILE` it writes the patched file there and leaves the original alone.
- `restore` strips the block and checks that the result matches the vanilla hash.

| Exit code | Meaning |
|---|---|
| 0 | ok |
| 1 | error, or verification failed |
| 2 | usage |
| 3 | already patched |
| 4 | unknown build |
| 5 | not patched |

## Web patcher

The same patch, in pure JavaScript, running entirely in your browser. You drop in `RoomLogic.lua`, it is patched and verified locally, and you download the result. The file is not uploaded and no game code is hosted. There is no WebAssembly and no server.

- URL: <https://jevonlipsey.github.io/hades2-43aspect/>
- Built by `bash tools/build_web.sh` into `web/dist/`.
- `node web/test/parity.mjs` checks that its output is byte-identical to `patch.py`.

## Verification

- `lua verify/test_nova43.lua` runs 32 checks against a stubbed engine (`brew install lua` on macOS). It exercises the 4:3 and 16:9 paths, the stack walk, the sentinel checks and the config switches.
- `node web/test/parity.mjs` checks that the browser output is byte-identical to `patch.py`.
- `node web/test/e2e.mjs [--expect-sha <hex>]` drives the web patcher end to end.
- `patch.py` itself verifies before it writes: the input must be a known vanilla build, the block must be present once afterwards, and removing it must give back the vanilla hash.

Supported build: Steam build 25481925.

| file | sha256 |
|---|---|
| vanilla `RoomLogic.lua` | `affb8ee3dc2806e1b9a1a5f8f8c3616f9d2010f267e58f175095f5c16e072d5b` |
| patched (patch v3) | `60608a7922268ee145d76743d125f2b00227d4d55e2d7603c9e3b4044e6bd402` |

The content files are byte-identical in the Windows and macOS builds, so the same file and patcher work for both. Game updates replace `RoomLogic.lua`, so re-patch afterwards. The patcher refuses unknown builds until it is updated.

## Install on the Retroid Pocket Nova

1. Set the game to fullscreen at 1280x960 (in game, or `X`/`Y` in `GlobalSettingsWin.sjson`).
2. The file on DroidDeck is
   `/root/.local/share/Steam/steamapps/common/Hades II/Content/Scripts/RoomLogic.lua`.
3. Either copy it out, patch it with the web patcher or on a PC, and copy it back, or run `python3 patch.py patch` against that folder in DroidDeck's desktop mode.
4. Keep `RoomLogic.lua.bak` next to it. It is your way back.

Tested on a Retroid Pocket Nova (DroidDeck, 1280x960).

## Build from source

No build is needed for the Lua block or `patch.py`. They are plain files.

```sh
lua verify/test_nova43.lua     # Lua block tests
bash tools/build_web.sh        # builds web/dist (the web patcher)
node web/test/parity.mjs       # browser output == patch.py output
node web/test/e2e.mjs
```

Tunables are in `CFG` at the top of `patch/nova43.lua`: `Enabled` per screen, `Cap`, `PivotDX` / `PivotDY` and `HideFrames`. In a running game they are also reachable as `Nova43.Config`. `python3 tools/preview.py` approximates the zoom from a device screenshot.

## Limits

- **Cropping is part of the design.** See [What gets cropped](#what-gets-cropped).
- **Keyword tooltips are not enlarged.** The engine draws them at a fixed size.
- **One supported build:** Steam build 25481925. Other builds are refused until the patcher is updated.
- **Mods:** the patch works by appending to `RoomLogic.lua`, like ModImporter. Because only a vanilla `RoomLogic.lua` is accepted, a file already edited by ModImporter is refused as an unknown build; patch first, then run ModImporter. Hell2Modding mods are not covered. Other mods that rebuild these screens may conflict.
- **Every other screen** is unchanged and still uses the vanilla layout.
