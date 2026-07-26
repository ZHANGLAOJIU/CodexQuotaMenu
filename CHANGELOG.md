# Changelog

## 2.3.0 - 2026-07-26

- Show the exact local reset timestamp directly under each quota meter.
- Keep the live reset countdown alongside the absolute date and time.
- Display an explicit unknown value when a quota window has no reset timestamp.
- Use isolated Swift module caches for reproducible local builds.

## 2.2.0 - 2026-07-13

- Identify 5-hour and weekly quotas by their window duration instead of API field order.
- Correctly show a weekly-only test window as `5h --% / W 100%`.
- Apply the same duration mapping to official API and local-log fallback data.
- Clamp malformed percentage values and preserve exhausted quota as 0% remaining.
- Add regression tests for single-window, exhausted, and malformed responses.

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
