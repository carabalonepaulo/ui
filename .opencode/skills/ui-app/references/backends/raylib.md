# Raylib + fontstash backend

This is the backend used by the `ui-demo` starter (`src/`). The library is
backend-agnostic; this document is one complete implementation, not a
requirement.

Raylib version in the vendored Odin package: 6.0 (OpenGL 3.3). Fontstash is the
Odin-native port in `vendor:fontstash`.

## Files

| File | Purpose |
| --- | --- |
| `src/main.odin` | Window, `ui.Callbacks`, frame loop, wheel smoothing, CLI. |
| `src/scale.odin` | Render target, physical-pixel callbacks, mouse/scissor mapping. |
| `src/renderer.odin` | Fontstash atlas, font registry, glyph quads. |
| `src/app.odin` | Shell and page lifecycle (`go_to`, `load_font`). |
| `src/pages/` | Page framework and screens. |

## Callbacks

```odin
ui.Callbacks {
    measure_text:      proc(font: Font, text: string, size, spacing: f64) -> Vec2,
    draw_text:         proc(font: Font, text: string, x, y, size, spacing: f64, color: Color),
    draw_rect:         proc(x, y, w, h: f64, color: Color),
    get_mouse_pos:     proc() -> Vec2,
    get_mouse_wheel:   proc() -> Vec2,
    is_mouse_pressed:  proc(btn: Mouse_Button) -> bool,
    is_mouse_released: proc(btn: Mouse_Button) -> bool,
    enable_scissors:   proc(x, y, w, h: i32),
    disable_scissors:  proc(),
}
```

The other fields are reserved. `get_delta_time`, `get_default_font`,
`load_texture`, `load_font`, `draw_texture`, `is_mouse_down/up`, and the key
callbacks are currently not called by the library.

All draw/measure coordinates from the UI are logical. The starter converts them
to the render target's physical pixels using `ppu = ui_scale * render_scale`.

## Render target

`src/scale.odin`:

```text
texture_size = ceil(dest_size * render_scale)
logical_size = texture_size / ppu
```

* `BeginTextureMode(target)` + `ClearBackground(BLANK)`.
* Run `ui.frame()`, the root scope, and the app draw inside one block.
* `EndTextureMode()`.
* `GenTextureMipmaps` + `TRILINEAR` when `render_scale > 2`; otherwise
  `BILINEAR`. (At exactly 2x, GL_LINEAR is a 2x2 box filter.)
* Present with `DrawTexturePro`. Raylib render textures are vertically flipped,
  so use a negative source height:

```odin
source := rl.Rectangle{0, 0, f32(tex.width), -f32(tex.height)}
dest := rl.Rectangle{dest_pos.x, dest_pos.y, dest_size.x, dest_size.y}
rl.DrawTexturePro(tex, source, dest, {0, 0}, 0, rl.WHITE)
```

`GenTextureMipmaps` logs at INFO every call. The starter raises the trace level to
`.WARNING` after init. If the log is useful, lower it again or only generate
mips when the content changes.

### Scissor

Raylib 5.5/6.0 flips scissor Y against `CORE.Window.currentFbo.height` when a
render target is active. Pass top-left coordinates in target pixels; do not flip
again:

```odin
rl.BeginScissorMode(px, py, pw, ph)
```

Clamp `px/py` to `[0, width/height]` and `pw/ph` to the remaining size before
calling. `EndScissorMode` only while the target is active.

### Mouse

```odin
if inside(dest_rect, mouse) {
    logical = (mouse - dest_pos) / dest_size * logical_size
} else {
    logical = {-1e9, -1e9}
}
```

## Text with fontstash

Fontstash keeps one single-channel atlas for all fonts and rasterizes glyphs at
the requested size. Raylib's default shader expects RGBA, so the starter mirrors
the dirty alpha region into white RGB + alpha and uploads that.

Key points:

* Set fontstash's size to `font_size * ppu`; set spacing to `spacing * ppu`.
* Use `location = .TOPLEFT` and `align_vertical = .TOP` so the UI's `y` is the
  top of the text box (raylib `DrawTextEx` semantics).
* Measure with `TextBounds` at the physical size and divide by `ppu`.
* Return `pixel_size` as the measured height so the library's line advance
  (`font_size + line_spacing`) stays consistent. Use line spacing for
  descenders.
* Do not upload the atlas after drawing the quads; upload first. The starter
  collects quads, flushes the atlas, then issues `DrawTexturePro` for each quad.
* If fontstash grows the atlas while iterating, normalized UVs change. Retry the
  whole string; the glyphs are cached, so the retry is cheap.
* `UpdateTextureRec` expects tightly packed rows for the sub-rectangle. Build a
  temporary buffer with `width = rec.width`, not a slice of the full atlas.
* Keep that staging buffer on the renderer using the normal allocator. A full
  atlas upload can exceed the UI frame arena (8 MB by default), especially at
  high `render_scale`. This was a real crash in the starter at `scale 4, ssaa 4`.
* Set the atlas filter to `.BILINEAR`. With pixel-snapped quads, `.POINT` also
  works; `.BILINEAR` avoids hard edges.
* A per-size glyph cache means changing `ui_scale` or `render_scale` creates new
  glyph sizes. That is normal; watch atlas growth.

The complete implementation is `ui-demo/src/renderer.odin`.

### Font registry behind `Context.load_font`

`pages.Context.load_font(name, size)` is implemented by `app_load_font`, which
calls `renderer_get_font`. The renderer keeps a `name -> ui.Font` registry.
Fontstash handles are size-independent, so `size` is a hint and the same handle
works at every `font_size`.

If you use raylib's own font atlases instead of fontstash:

```odin
font := rl.LoadFontEx(path, i32(size * ppu), codepoints, count)
rl.DrawTextEx(font, cstr, {x * ppu, y * ppu}, size * ppu, spacing * ppu, color)
```

Key the font cache by `(name, size * ppu)` and reload when `ppu` changes.
Otherwise a 2x atlas sampled at 1.5x or 3x blurs.

## Frame loop

```odin
ui_scale_init(&app.scale, 1, 2)
renderer_init(&app.renderer)
ui.init(CALLBACKS, 65536, 8 * mem.Megabyte)
app_init()               // pages load their fonts through Context

for !rl.WindowShouldClose() {
    handle_input()

    rl.BeginDrawing()
    rl.ClearBackground(window_bg)
    ui_poll(app_draw)     // scale target + ui.frame/root scope + present
    rl.EndDrawing()
}
```

Order matters for teardown: `app_deinit` (pages) before `ui.deinit`, then the
render target, then the renderer/window.

## Screenshots

Raylib batches draw calls. Reading the framebuffer before `EndDrawing` sees a
black frame unless the batch is flushed:

```odin
rlgl.DrawRenderBatchActive()
image := rl.LoadImageFromScreen()
rl.ExportImage(image, path)
rl.UnloadImage(image)
```

`TakeScreenshot` flushes internally but prepends the working directory and
documents that its filename must not contain a path. Use
`LoadImageFromScreen` + `ExportImage` if you need arbitrary paths.

## High-DPI

`GetScreenWidth/Height` are window coordinates; `GetRenderWidth/Height` can be
the physical framebuffer. Mouse positions are in window coordinates. Pick one
destination space and be consistent. Setting `render_scale` to the DPI scale is
a simple way to get a physical-resolution target while keeping screen-coordinate
layout.

## Run the starter

```sh
git clone https://github.com/carabalonepaulo/ui-demo.git my-app
cd my-app
just setup     # clones carabalonepaulo/ui into ./ui
just run
```

Without `just`:

```sh
git clone https://github.com/carabalonepaulo/ui.git ui
odin run src -collection:ui=ui
```

Headless check:

```sh
odin run src -collection:ui=ui -- --screenshot out.png --view 2 --scale 1.5 --ssaa 3
```
