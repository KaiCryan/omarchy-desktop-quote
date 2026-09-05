# Desktop Quote

A **Variety-style quote overlay for [Omarchy](https://omarchy.org)**.

It draws a small quote placard on your desktop — behind your windows, over the
wallpaper — and rotates it on a timer *and* every time the wallpaper changes.
Quotes come from a plain-text file you control. The text is a live overlay, not
baked into the wallpaper, so it restyles with your theme and you can keep the
wallpaper and quote pools completely separate.

![preview](docs/preview.jpg)

<sub>Shown at the default `bottom-left` position. Nine positions and a text-size
scale are configurable — see [Config](#config).</sub>

## Why

Omarchy cycles wallpapers beautifully but has no equivalent of Variety's quote
feature. This adds it, as a first-class shell plugin: it uses the same layer the
wallpaper renderer does, picks up your theme's colours and font, and needs no
extra daemon.

## Requirements

- Omarchy with the Quickshell-based shell (`omarchy-shell`) — i.e. current
  Omarchy. No other dependencies, unless you use `position: "<vertical>-auto"`
  (see [below](#auto-side-position-vertical-auto)), which shells out to
  ImageMagick (`magick`).

## Install

```bash
omarchy plugin add https://github.com/KaiCryan/omarchy-desktop-quote
omarchy plugin enable kaicryan.desktop-quote
```

> Plugins run as unsandboxed code inside `omarchy-shell`. Read `Service.qml`
> before you enable it — it's ~250 lines and has no network access.

Update later with `omarchy plugin update kaicryan.desktop-quote`, remove with
`omarchy plugin remove kaicryan.desktop-quote`.

## Your quotes

Create **`~/.config/omarchy/quotes.txt`**:

```
# one quote per line — "quote | Attribution", attribution optional
# lines starting with # and blank lines are ignored

The work is mysterious and important.
A handshake is available upon request. | Seth Milchick
Simplicity is the ultimate sophistication. | Leonardo da Vinci
```

It **hot-reloads on save**. Until that file exists, a small bundled set is shown
(see [`quotes.txt`](quotes.txt); there's also [`examples/quotes.txt`](examples/quotes.txt)).

## Config

Optional — create **`~/.config/omarchy/desktop-quote.json`**
([example](examples/desktop-quote.json)). Also hot-reloads.

| key | default | meaning |
|---|---|---|
| `quotesPath` | `~/.config/omarchy/quotes.txt` | where to read quotes from |
| `rotateMinutes` | `30` | minutes between automatic changes |
| `syncWithWallpaper` | `true` | also change the quote when the wallpaper changes |
| `position` | `bottom-left` | `<vertical>-<horizontal>` — vertical: `top` \| `middle` \| `bottom`, horizontal: `left` \| `center` \| `right` \| `auto`. e.g. `middle-right`, `top-center`, `middle-auto`. (`corner` still works as an alias.) |
| `marginX` / `marginY` | `96` / `84` | distance from the screen edges, px |
| `maxWidth` | `720` | wrap width of the quote, px |
| `fontScale` | `1.0` | multiplier on the text size |
| `layer` | `bottom` | `bottom` = on the desktop (behind windows) · `top` = floats over windows |
| `dim` | `0.92` | overall opacity, `0`–`1` |

### Auto side (`position: "<vertical>-auto"`)

With the horizontal segment set to `auto` (e.g. `middle-auto`), the plugin picks
left or right per wallpaper instead of a fixed side: it crops the actual
candidate placard rectangle on each edge and compares grayscale variance —
lower variance (flatter, less busy) wins. Re-evaluated every time the
wallpaper changes, via [`bin/detect-quote-side`](bin/detect-quote-side).
Requires `magick` (ImageMagick) on `PATH`; without it, `auto` just falls back
to the right.

## Commands

```bash
omarchy-shell -q desktopQuote next     # jump to another quote now
omarchy-shell -q desktopQuote toggle   # hide / show
omarchy-shell -q desktopQuote hide
omarchy-shell -q desktopQuote show
```

Bind one in `~/.config/hypr/bindings.lua`, e.g.:

```lua
o.bind("SUPER + SHIFT + Q", "New desktop quote", "omarchy-shell -q desktopQuote next")
```

Pair it with wallpaper cycling so both step together:

```lua
o.bind("SUPER + Next", "Next wallpaper + quote",
  "omarchy theme bg next ; omarchy-shell -q desktopQuote next")
```

With `syncWithWallpaper` on (the default) the quote would follow the wallpaper on
its own within a second or two; calling `next` in the same binding just makes it
instant. The plugin de-bounces so it only changes once.

## Notes

- On a full workspace the desktop is covered, so on `layer: "bottom"` you'll see
  the quote in the window gaps or on an empty workspace. Set `layer: "top"` to
  keep it always visible.
- Colours are `Color.foreground` (quote) and `Color.accent` (bar + attribution)
  from your current Omarchy theme.

## License

MIT © kaicryan. The bundled fallback quotes are lines from *Severance*
(Apple TV+) — included as example content for personal use only.
