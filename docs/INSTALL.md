# Installing the Hades II 4:3 UI patch

This patch makes the boon-selection and dialogue screens of Hades II fill a 4:3 screen such as the Retroid Pocket Nova, so their text is readable. You patch **your own copy** of `RoomLogic.lua`; nothing from the game is downloaded or shared. This is an unofficial fan tool, not affiliated with or endorsed by Supergiant Games.

## Quick summary

- The patched file **replaces** `RoomLogic.lua` in the game's `Content/Scripts` folder. No other file is touched.
- **Always keep a backup** of the original (`RoomLogic.lua.bak`).
- Supported: Steam build 25481925. **Re-patch after every game update.** Steam updates overwrite the file, and the patcher refuses a file that is already patched, so always patch the fresh original.

## 1. Get the patched file

Pick one. Both produce the same patch, byte for byte.

### a) Web patcher (any device, including your phone)

1. Open the web patcher: <https://jevonlipsey.github.io/hades2-43aspect/>
2. Drop in (or pick) your `RoomLogic.lua`.
3. Wait for it to patch and verify. Everything runs in your browser; the file is not uploaded.
4. Download the patched `RoomLogic.lua` and put it in the `Scripts` folder (see [section 2](#2-where-the-file-is)). Keep the original as a backup first.

### b) Desktop patcher (`patch.py`)

You need Python 3.8 or newer. There is nothing to install. Get `patch.py` and the `patch/` folder from a clone of the repo: <https://github.com/jevonlipsey/hades2-43aspect>

```
python3 patch.py status <target>
python3 patch.py patch  <target>
```

`<target>` is `RoomLogic.lua` itself, the `Scripts` folder, the `Content` folder or the game folder. Examples:

| System | Command |
|---|---|
| Windows | `python patch.py patch "C:\Program Files (x86)\Steam\steamapps\common\Hades II"` |
| macOS | `python3 patch.py patch "$HOME/Library/Application Support/Steam/steamapps/common/Hades II/Hades II.app/Contents/Resources/Content/Scripts"` |
| Linux / Steam Deck | `python3 patch.py patch "$HOME/.local/share/Steam/steamapps/common/Hades II"` |

`patch` verifies the result, **backs up the original to `RoomLogic.lua.bak`** (an existing backup is never overwritten) and installs the patched file. Add `--out FILE` to write the patched file somewhere else and leave the original alone. `status` tells you whether the file is vanilla, patched or unknown, and changes nothing.

Exit codes: `0` ok, `1` error or verification failed, `2` usage, `3` already patched, `4` unknown build, `5` not patched (for `restore`).

## 2. Where the file is

| Platform | `RoomLogic.lua` |
|---|---|
| DroidDeck (internal proot environment) | `/root/.local/share/Steam/steamapps/common/Hades II/Content/Scripts/RoomLogic.lua` |
| Windows (Steam) | `C:\Program Files (x86)\Steam\steamapps\common\Hades II\Content\Scripts\RoomLogic.lua` |
| Linux / Steam Deck | `~/.local/share/Steam/steamapps/common/Hades II/Content/Scripts/RoomLogic.lua` |
| macOS | `~/Library/Application Support/Steam/steamapps/common/Hades II/Hades II.app/Contents/Resources/Content/Scripts/RoomLogic.lua` |

Easiest way to open it: in Steam, right-click Hades II, then **Manage**, then **Browse local files**.

**macOS is different:** the game is an app bundle. Right-click `Hades II.app` and choose **Show Package Contents**, then go to `Contents/Resources/Content/Scripts/`.

The content files are byte-identical in the Windows and macOS builds, so the same patch works on both.

## 3. Android handhelds

Both apps below run the Windows game inside their own Linux/Wine environment, so the game's files are usually **not** in a normal Android folder. The steps here are what has been confirmed on the author's device or from public sources; anything else is marked **(unconfirmed)**. Your app's version may differ.

The easiest route on Android is the web patcher on the phone itself:

1. Copy `RoomLogic.lua` out of the game's `Content/Scripts/` folder to somewhere your browser can pick it (for example `Download/`). Keep this copy as your backup.
2. Open the web patcher (<https://jevonlipsey.github.io/hades2-43aspect/>) in the phone's browser and pick that file.
3. Download the patched file.
4. Copy it back over the original in `Content/Scripts/`.

Or patch on a PC and copy the patched file over (any file transfer you like).

### DroidDeck

DroidDeck runs Valve's ARM64 Steam client inside an in-app proot Linux runtime, with Windows games running through Proton. See the [DroidDeck site](https://droiddeck.app/). Be careful to use the right app: there is an unrelated project of the same name that is a Stream Deck controller.

- Inside DroidDeck's Linux environment (for example via its desktop terminal or file manager), the file is at
  `/root/.local/share/Steam/steamapps/common/Hades II/Content/Scripts/RoomLogic.lua`
- Copy `RoomLogic.lua` out to your Android storage, or patch it directly in desktop mode with `python3 patch.py patch` **(unconfirmed that Python is installed in your DroidDeck; the web patcher does not need it)**.
- The game's log and settings are inside the Proton prefix:
  `/root/.local/share/Steam/steamapps/compatdata/1145350/pfx/drive_c/users/steamuser/Saved Games/Hades II/`
  (`Hades II.log`, `GlobalSettingsWin.sjson`).

On the Retroid Pocket Nova the boon screen has been tested and approved. The dialogue zoom is installed but **not yet confirmed on the device**.

### GameNative

[GameNative](https://github.com/utkarshdalal/GameNative) runs games you own from Steam, Epic, GOG and Amazon through Wine with Box64. Setup guide: [retrohandhelds.gg](https://retrohandhelds.gg/gamenative-setup-guide/).

- GameNative stores containers in the app's private data directory. Since Android 13 a normal file manager cannot open it. Whether your version exposes it is **(unconfirmed)**.
- Users report an **Open container** action that gives access to the container's Windows-style drives. **The exact menu is unconfirmed; check your app's file manager and docs.**
- Rooted devices (or a Shizuku-style file manager) can reach app data directly. **(unconfirmed for this use)**
- The Hades II game folder location inside a GameNative container, and whether Hades II runs well there at all, are **(unconfirmed)**.

Display settings for GameNative containers: **unconfirmed; check your app's container settings.** The goal is the same as below: give the game a 4:3 screen.

## 4. Display settings

The patch only helps if the game is drawing at a 4:3 resolution.

1. In the game, set the display to **fullscreen at the screen's 4:3 resolution**. On the Retroid Pocket Nova that is 1280x960.
2. You can also set it in `GlobalSettingsWin.sjson` (in `Saved Games/Hades II/`): `X = 1280`, `Y = 960`. Close the game first.
3. On DroidDeck, the container must hand the game a 4:3 surface, or bars remain. In the settings cog set **Resolution** to `Match screen (1280x960)` and **16:9 game fit** to `Stretch` (off). Both apply on the **next session**, so fully exit and relaunch the app and the game. These names come from testing on a Retroid Pocket Nova; other versions may label them differently.

On a wider screen (a 16:9 monitor) nothing changes: the patch does nothing at 16:9. At 16:10 it zooms by 1.111 instead of 1.333.

## 5. Checking it worked

- Open a boon choice. The three slots and their text should fill the screen, with no frame art in bands above and below.
- Open a dialogue. The portrait and text should fill the screen the same way.
- Other screens look the same as before.

If you want to be sure the block is installed without starting the game, run `python3 patch.py status <target>`. It should report `patched (nova43), restorable to vanilla: yes`.

## 6. Troubleshooting

| Problem | What to do |
|---|---|
| Menus still look small | Check the display settings (section 4). The game must be at a 4:3 resolution. At 16:9 the patch does nothing by design. Then run `python3 patch.py status` to confirm the file is patched. |
| Game will not start / black screen | Restore `RoomLogic.lua.bak` over `RoomLogic.lua`. If the problem is gone, the patch does not suit your setup; open an issue with your `Hades II.log`. |
| "already patched" (exit code 3) | The file is already patched. Restore the original (`.bak`, or Steam **Verify integrity of game files**) and patch that. |
| "unknown build" (exit code 4) | The file is not the supported build (Steam build 25481925), or another mod has edited `RoomLogic.lua`. Nothing is written. The game was probably updated; wait for a new release or open an issue. On macOS make sure you picked the file inside `Hades II.app` (section 2). |
| It stopped working after a game update | Steam replaced the file. Patch the new original again. If the patcher says unknown build, the patch has not been updated for that build yet. |
| The patch is installed but the screens are vanilla | At load the block checks the game's data against expected values. If the game's scripts differ, it disables itself and the game runs vanilla (the shipping game does not log this). Run `python3 patch.py status` to confirm the file is patched; if it is, the game has probably updated, so open an issue. |
| Keyword tooltips are still small | Expected. The engine draws them at a fixed size and the patch cannot scale them. They keep their vanilla position. |
| I want vanilla back | See Uninstall below. |

## 7. Uninstall

Any of these:

- `python3 patch.py restore <target>` strips the block and checks the vanilla hash.
- Copy `RoomLogic.lua.bak` back over `RoomLogic.lua`.
- In Steam, right-click Hades II, then **Properties → Installed Files → Verify integrity of game files**.
