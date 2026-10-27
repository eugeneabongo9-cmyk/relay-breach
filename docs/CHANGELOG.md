# Changelog

## Unreleased

- Fix the Actions workflow. GitHub rejected the first file as invalid YAML (run 40578775847) before any job started. The install step no longer uses a glob.
- Step the player and enemies with the tick delta. `move_and_slide` follows the engine frame delta, so a tight headless loop did not cross the tutorial bay.
- Add a screenshot of the tutorial bay from the web build.

## 0.9.0

- First playable slice: tutorial, four encounters, finale, three upgrades.
- Tether rules, enemy FSM, room-boundary saves, settings, procedural presentation.
- Headless test run and web/Linux export against Godot 4.7.2.
- Desktop frame time left unverified. Version is not 1.0 for that reason.
