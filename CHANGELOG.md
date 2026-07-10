# Changelog

## 2.1.0 - 2026-07-10

- Add a native graphical quota panel with separate 5-hour and weekly meters.
- Show remaining percentage and live reset countdown under each meter.
- Color low remaining quota red, medium quota orange, and healthy quota blue.
- Keep exact reset timestamps and manual sync actions in the menu.

## 2.0.0 - 2026-07-10

- Read live quota data from the current Codex usage endpoint.
- Refresh automatically every 30 seconds.
- Fall back to recent local Codex response headers when necessary.
- Show the active data source and sync timestamp in the menu.
- Support the current Codex desktop application bundle path.
- Add source build, per-user install, and uninstall scripts.
