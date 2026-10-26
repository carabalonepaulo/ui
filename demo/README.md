# Odin UI demo

A small, complete application built with the `ui` package in this repository.
It is the reference backend for raylib, fontstash, and supersampled scaling.

## Run

From `demo/`:

```sh
just run
```

From the repository root:

```sh
odin run demo
```

Build only:

```sh
odin build demo -out:demo.exe
```

## What it shows

* An app shell with a header, sidebar, content area, and footer, built with
  `scope_at` and `flex`.
* A virtualized, scrollable grid of cards with hover/press state.
* A typography view with word-wrapped, vertically scrollable fontstash text.
* A scaling inspector that explains and visualizes the render-target technique.
* A debug profiler overlay (`D`).
* Live controls for `ui_scale` and `render_scale`.

## Controls

| Input | Action |
| --- | --- |
| Mouse wheel | Scroll the grid or the typography panel |
| `-` / `=` | UI scale down / up (0.5x to 1.5x) |
| `[` / `]` | Supersampling down / up (1x to 4x) |
| `R` | Reset scale to 1x and supersampling to 2x |
| `D` | Toggle the UI profiler |
| Sidebar `-` / `+` | Same scale controls with the mouse |

## Files

| File | Purpose |
| --- | --- |
| `main.odin` | App state, callbacks, smooth wheel, frame loop, CLI args. |
| `scale.odin` | Offscreen target lifecycle, physical-pixel callbacks, mouse mapping, scissor. |
| `renderer.odin` | Fontstash atlas (RGBA mirror), glyph rasterization at physical size, text quads. |
| `app.odin` | All UI drawing: shell, nav, cards, typography, scaling inspector, footer. |

## How the scaling works

The UI works in logical pixels. For a window of `dest_size`:

```text
pixels_per_unit = ui_scale * render_scale
texture_size    = ceil(dest_size * render_scale)
logical_size    = texture_size / pixels_per_unit
```

The UI renders into the texture, and the texture is blitted to the window. All
backend callbacks convert logical coordinates to texture pixels; text is
rasterized at `font_size * pixels_per_unit`. `render_scale > 1` is supersampling:
the texture is larger than the window and is downsampled at the end.

`render_scale = 2` uses bilinear downsampling, which is a 2x2 box filter at that
exact ratio. Higher factors generate mipmaps (or you can replace that with a
box-filter shader).

See `../.opencode/skills/ui-app/references/scaling.md` for the full explanation
and the pitfalls of the older camera-based version.

## Headless screenshots

For visual checks:

```sh
odin run . -- --screenshot out.png --view 2 --scale 1.5 --ssaa 3
```

`--view` is `0` (dashboard), `1` (typography), or `2` (scaling). The app exits
after writing the screenshot. Raylib batches draw calls, so the demo flushes the
batch before reading the framebuffer.

## Notes

* Fonts live in `assets/fonts/` and are loaded by `renderer.odin`; the path
  helper accepts both `demo/assets/...` and `assets/...` working directories.
* The demo uses `demo/../ui` as a relative import. If you copy it elsewhere,
  change the import or add a collection (`-collection:ui=path/to/ui`).
* The library's text tokenizer splits on spaces only; the demo's paragraphs are
  single strings without newlines.
