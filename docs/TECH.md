# Technical Notes and Project Layout

This file documents the basic technical architecture for the prototype and where to find source files.

Project layout (important folders):
- scenes/ — Godot .tscn scene files (main.tscn, player.tscn, area scenes)
- scripts/ — GDScript files attached to scenes (player.gd, perfect_stride.gd, terrain_area.gd, obstacle.gd)
- ui/ — HUD scene and script
- assets/ — placeholder VFX and art
- config/ — gameplay JSON tunables
- docs/ — GDD and other docs

Godot version: 4.x (use 4.1+)

Notes:
- The prototype uses JSON for tuning (`res://config/gameplay.json`). You may convert to Godot .tres later.
- Run the `main.tscn` scene inside the Godot editor after opening the project. If input actions are missing, run the editor helper in `scripts/editor/register_inputs.gd` inside the editor or add the InputMap entries manually.
