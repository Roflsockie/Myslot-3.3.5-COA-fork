# Myslot 3.3.5 COA fork

A fork of [Myslot 6.3.0](https://github.com/tg123/myslot) for WoW 3.3.5a / Ascension / Conquest of Azeroth (`## Interface: 30300`).

The addon transfers action bar layouts, macros and keybindings between characters — including the keybindings of the action buttons themselves (`ACTIONBUTTON*`, `MULTIACTIONBAR*`), which ActionBar Saver does not provide.

Русская версия: [README_RU.md](README_RU.md).

## Credits

- **Original addon:** Boshi Lian (farmer1992@gmail.com), <https://github.com/tg123/myslot>. The original author is kept in `Myslot.toc` and in the source code.
- **Fork author:** Miss Click.
- Fork repository: <https://github.com/Roflsockie/Myslot-3.3.5-COA-fork>.
- The original Apache 2.0 license is kept in `LICENSE`.

## Features

- Export/import of action bars: spells, macros, items, pets, companions, mounts, flyouts and empty slots.
- Macros: the General tab and the per-character tab are two separate sets (36 + 18 slots).
- Keybindings, including bindings of action buttons and multi-action bars.
- Profiles: save, load, rename, delete and share through chat links.
- Ignore settings (Action Bars / Key Binding / Macro / CVars) in both Import and Export menus and in the options panel.
- Minimap icon and an options panel under Interface Options.

## Differences from the original 6.3.0

1. **3.3.5a only.** The TOC declares `Interface: 30300` instead of the retail flavor list. Everything absent in 3.3.5 is disabled by guards instead of throwing errors.

2. **`compat_335.lua` loads first.** A small compatibility layer provides:
   - `tAppendAll`, `IsPetActive()` via `PetHasActionBar()`;
   - `WrapTextInColorCode` for the font color constants;
   - `C_Timer` (`After`, `NewTimer`, `NewTicker` with `:Cancel()`) driven by a hidden OnUpdate frame;
   - `C_UI.Reload` and flat `C_EquipmentSet.*` wrappers;
   - a private `MyslotCompatSettings` instead of a global `Settings` — a global one makes AceConfigDialog and LibCompat in other addons take retail code paths and fail;
   - `MenuUtil` / `Menu` / `AnchorUtil` rendered through the classic `UIDropDownMenu`.

3. **Spells are restored by name.** In 3.3.5 `PickupSpell` takes a spellbook slot, not a spell ID. The fork builds a `name → slot` map with `GetSpellTabInfo` + `GetSpellName` (the same way ActionBar Saver does) and stores the spell name in the export. An unlearned talent is never replaced by a random spell: the slot is cleared and a warning is printed.

4. **Macros.** Icon texture paths are converted to numeric indices via `GetMacroIconInfo`. Global and per-character tabs no longer collapse into one: the 36/18 slot constants are fixed and macro lookup is scoped to the source tab. Exports contain both tabs.

5. **Keybindings.** `GetBinding(index)` + `GetBindingKey(command)` are used instead of `GetBinding(index, true)` (the second argument is a binding mode in 3.3.5). `SetBinding` is called without a retail context. As a result, action bar bindings are exported and restored correctly.

6. **Menus.** Refreshing a checkbox closes all open `UIDropDownMenu` levels before rebuilding, so the menu window is not duplicated on every click.

7. **Small GUI fixes.** The Import/Export arrows are drawn in the `OVERLAY` layer, and the export edit box takes focus on click so Ctrl+C works.

8. **Retail-only features are unavailable in 3.3.5:** talent loadout application, Cooldown Manager, click bindings, transmog outfits, `C_PetJournal` / `C_MountJournal`. As in the original for classic clients, the talent point spread (`0/0/0`) is still written to the export header.

9. **Feedback link** in `Myslot.toc`, in the options panel and in the export header now points to this repository.

## Installation

Copy the `Myslot` folder into `World of Warcraft\Interface\AddOns\Myslot` and run `/reload`. Keep the folder name `Myslot` — the icon path and addon metadata depend on it.

## Verification

- Static call/TOC check with `wow335/verify-addon.mjs`: `exit 0`, 0 unresolved APIs, TOC `Interface 30300`.
- A full round trip between two characters was tested on the CoA 3.3.5 client by the user: export and import of skill bars, macros (both tabs), action bar keybindings, and the Import/Export checkbox menus.

## Known limitations

- Settings and the custom CoA Lua API delta were checked against the 3.3.5 index and client binary scans; undocumented server-side behavior may differ.
- Retail talent/outfit branches remain unavailable on 3.3.5 because the corresponding APIs do not exist in that client.

Bug reports and feedback: <https://github.com/Roflsockie/Myslot-3.3.5-COA-fork/issues>.
