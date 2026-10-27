# Accessibility

- Remap in Settings. A key claimed by another action is swapped, not dropped. Esc cancels a listen. Shift+F10 or "Reset bindings" restores defaults even in a release build, and the binding list is stored in `user://settings.json`.
- Menus use Godot focus and the existing `ui_*` actions (arrows and accept). Touch buttons are at least 64 px and the stick is 150 px.
- UI scale slider 0.8–1.6 rewrites font sizes.
- Master, music, and effects buses.
- Camera shake and the full-screen damage flash can be turned off. Damage still plays a sound. Enemy attacks show a growing ring and a "!" so they are not color-only. Endpoints use a distinct mesh plus a text glyph.
- Reduced shake forces trauma to zero. Reduced flash skips the red overlay.

Not done: screen-reader labels, color-blind simulation, a tested hardware gamepad on a real device (the map exists; no controller was attached here).
