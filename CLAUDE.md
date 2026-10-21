# hades2-43aspect

Makes Hades II's boon-selection and dialogue screens readable at 4:3 (Retroid Pocket Nova, 1280x960). Gameplay already runs natively at 4:3; this patch touches only those two UI compositions.

## Commands

```sh
lua verify/test_nova43.lua                 # stubbed-engine tests for the Lua block (brew install lua)
python3 patch.py status  <RoomLogic.lua|Scripts|Content|game dir>
python3 patch.py patch   <...> [--out FILE] # verified; writes RoomLogic.lua.bak once, never overwrites it
python3 patch.py restore <...>              # strips the block, checks the vanilla sha256
node web/test/parity.mjs                   # browser output must be byte-identical to patch.py
bash tools/build_web.sh                    # builds web/dist
node web/test/e2e.mjs [--expect-sha <hex>] # end-to-end test of the web patcher
python3 tools/preview.py ...               # approximates the zoom from a device screenshot
```

## Engine facts (build 25481925, verified)

- SGG engine on The Forge, Lua 5.2 (`Ship/lua52.dll`). Scripts are loose `Content/Scripts/*.lua`. The engine binary only names `Main.lua` and `RoomLogic.lua`; `RoomLogic.lua` imports everything else at its top, so code appended at its end runs after all game scripts are loaded. That is the same injection point the Hades II ModImporter uses.
- Content files are byte-identical between the macOS and Windows builds (689 Lua/GUI/en-text files compared), so one hash list covers both.
- Native 4:3: `UpdateConfigOptionCache` (`RunLogic.lua:2464`) keeps width 1920 and grows height. At 4:3 that gives `ScreenHeight` 1440, `ScreenScaleY` 1.333, `ScreenCenterNativeOffsetY` 180, `ScreenState.NeedsLetterbox` true. The 1920x1080 menu layouts sit centred, with `NativeAspectRatioFrame` art in the bands.
- Boon screen: `OpenUpgradeChoiceMenu` and `CreateUpgradeChoiceButton` (`UpgradeChoiceLogic.lua`). Slot i is at `(ScreenCenterX-5, ScreenCenterY-190+256(i-1))`. Text is attached to the slot. The description uses `BaseFormat` (LatoMedium 19.5), Width 921.5.
- Dialogue: `DisplayTextLine` (`NarrativeLogic.lua:652`) places the portrait, bubble, nameplate, text (Width 833, FontSize 24) and prompt at hard-coded `ScreenCenterX/Y` offsets. It waits for input, so never change globals around it.
- `thread()` resumes the new coroutine immediately (`Main.lua:413`). Saves use whitelists, and there is no `SaveIgnores`.

## How the patch works

`patch/nova43.lua` is appended to `RoomLogic.lua` between `-- >>> nova43` and `-- <<< nova43 <<<` markers, with CRLF line endings like the game files.

- It wraps `CreateScreenObstacle`, `CreateTextBox`, `Attach`, `Teleport`, `SetScale`, `CreateAnimation` and `SetInteractProperty`.
- A rewrite only happens when the calling coroutine's stack contains one of these layout functions:
  - `CreateUpgradeChoiceButton` or `TraitLockedPresentation` (Boon);
  - `CreateScreenFromData` called by `OpenUpgradeChoiceMenu` (Chrome);
  - `DisplayTextLine` (Dialogue).
- Boon and Chrome share one zoom: `ScreenScaleY` (capped by `CFG`), pivot `ScreenCenterX-390`.
- Chrome keeps text anchors and the header centred, and moves the action bar (native y >= centre+360) into the bottom band unscaled.
- Dialogue zooms about the screen centre, including the context art.
- `AltAspectRatioFramesShow` is skipped when called from `OpenUpgradeChoiceMenu` or `DisplayTextLine`.
- On a 16:9 canvas there's no stack walk and no change.
- At load the block checks sentinel values in the game data, and stays off if they don't match.
- Tunables are in `CFG` at the top of the block. In a running game they're also reachable as `Nova43.Config`.

## Web patcher

Pure JavaScript, no WASM, so there is no worker or `_framework` and it deviates from the chefrpg shell. `style.css` stays byte-identical with the other repos. The core is `web/app/nova43-core.js`. Its data is generated from `patch.py` by `tools/gen_web_data.py`. The parity test guards byte-identity with `patch.py`.

## Rules

- `original/` holds pristine files pulled from the device. It's gitignored and read-only.
- Never commit or ship game files, patched or not. The patcher ships only our own Lua block.
- Device procedure lives in the nova-43aspect skill. Live device state and rollback steps go in `CLAUDE.local.md`.
- Commit, push and publish only when the user asks.
