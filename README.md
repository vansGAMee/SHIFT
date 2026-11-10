# SHIFT · 1.1.0

A first-person story puzzle game about memory, loss, and finding a way forward. Fourteen connected rooms, a mountain prologue, one exchange of two circuit states in each room, and a complete ending.

**English is the default language.** Switch between English and Russian in Settings → Language / Язык. Both versions include menus, subtitles, interactions, puzzle diagrams and environmental signs.

## Play

[Download SHIFT 1.1.0 for Windows or Linux](https://github.com/vansGAMee/SHIFT/releases/tag/v1.1.0), then extract the whole archive.

- Windows: run `SHIFT.exe`.
- Linux: run `Play.sh` or `SHIFT.x86_64`. If needed: `chmod +x Play.sh SHIFT.x86_64`.
- On the author's workstation: `./Играть в SHIFT.sh` launches the latest Linux build.

Godot and an internet connection are not required to play. The game uses OpenGL Compatibility rendering and requires a keyboard and mouse.

## Controls

WASD moves, mouse or arrows look. E interacts. Select two marked circuits with RMB; Shift or Space swaps their states. Q clears the selection. R restarts the room after confirmation. F inspects the rifle. Esc opens the menu. F11 toggles fullscreen.

The prologue starts lying on the mountain: look around, inspect the nearby objects, or press E after a few seconds to continue. The rifle is a story object. There is no combat puzzle to solve with it.

Settings include separate volume sliders, sensitivity, image detail, camera sway, reduced flashes and distortion, optional pursuit, and streamer mode. Progress saves between rooms; continuing resets an unfinished room's puzzle.

## Music and credits

Concept, creative direction, game design and the two original tracks belong to SHIFT's author. Development and visual implementation used AI tools under the author's direction. Full credits: [CREDITS.md](CREDITS.md).

The author's `shift1.mp3` plays quietly once in room four. The author's `shift.mp3` plays once during the final scene and continues over the credits. Streamer mode mutes all music. The Second's reveal still creates an eight-second music break with a gradual return.

## Build from source

Open `project.godot` in Godot 4.5.1 with its Linux and Windows export templates installed. Export presets are included. Large engine binaries, caches, personal saves, Wine prefixes and generated builds are not stored in Git.

```sh
godot --headless --editor --path . --import --quit
godot --headless --fixed-fps 60 --path . -- --campaign-test
godot --headless --fixed-fps 60 --path . -- --release-test
godot --headless --path . --export-release Linux
godot --headless --path . --export-release Windows
python3 tools/package.py
```

Source strings and the English catalog live in `assets/localization/en.json`; Russian remains available as the original story language. Tests run in automation mode and do not write the player's save. Save/startup tests require isolated profiles as described in `TESTING.md`.

Режим English включён по умолчанию. Русский выбирается в Settings → Language / Язык. Авторская музыка и участие ИИ указаны в титрах на обоих языках.
