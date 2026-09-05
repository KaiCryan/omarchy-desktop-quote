# Changelog

## 1.3.0
- `position` accepts `auto` as the horizontal segment (e.g. `middle-auto`):
  picks whichever side of the current wallpaper has more empty space for the
  placard, re-evaluated on every wallpaper change. New `bin/detect-quote-side`
  helper (shells out to ImageMagick; falls back to the right without it).

## 1.2.1
- Default `rotateMinutes` is now `30` (was `20`).

## 1.2.0
- Accent is now a short horizontal tick above the quote (on its leading edge)
  instead of a vertical bar — the bar hugged the screen edge and looked wrong at
  right/center positions.
- De-bounce the wallpaper-sync roll: a keybind that cycles the wallpaper *and*
  calls `next` in one line now changes the quote once, not twice.

## 1.1.1
- Fix `FileView` usage so the quotes file actually loads.

## 1.1.0
- `position` config: `<top|middle|bottom>-<left|center|right>` — nine placements
  (the old `corner` key still works as an alias).
- Full-screen input-masked surface so the placard can sit anywhere and never
  intercepts clicks.
- Soft drop shadow for legibility over any wallpaper.
- `toggle` / `show` / `hide` IPC commands alongside `next`.
- `quotesPath` config; bundled fallback quotes when no user file exists.

## 1.0.0
- Initial release: rotating desktop quote placard, plain-text quotes file,
  re-rolls on a timer and when the wallpaper changes.
