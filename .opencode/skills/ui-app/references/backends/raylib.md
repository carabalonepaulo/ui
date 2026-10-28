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
| `src/scale.odin` | rlgl modelview scale, physical-pixel callbacks, mouse/scissor mapping. |
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

All draw/measure coordinates from the UI are logical. The starter runs the whole
frame under an rlgl modelview scale of `ppu = ui_scale * dpi_scale`, so every
draw call (including `rl.Draw*` calls a component makes directly) becomes
physical pixels. No render target is involved.

## Modelview scale

`src/scale.odin`:

```text
ppu          = ui_scale * dpi_scale
logical_size = window_size / ppu
```

* `rlgl.PushMatrix()` + `rlgl.Scalef(ppu, ppu, 1)` before `ui.frame()`.
* `ui.frame()`, the root scope, and the app draw inside one block.
* `rlgl.PopMatrix()` after the block.

rlgl bakes the transform into the vertices on submission, so the matrix costs
nothing, does not flush the batch, and can be pushed/popped mid-frame (the text
callback does exactly that).

In raylib 6 the matrix API lives in `vendor:raylib/rlgl`
(`rlgl.PushMatrix`, `rlgl.Scalef`, `rlgl.PopMatrix`), not in `rl`, and it needs
`import rlgl "vendor:raylib/rlgl"`.

Consequences for the callbacks:

* `draw_rect` draws in logical units; no `* ppu`.
* `draw_text` pops the matrix, draws at `size * ppu`, pushes it back.
* `measure_text` measures at `size * ppu` and returns `physical / ppu`.
* `enable_scissors` still converts to framebuffer pixels (`glScissor` is not
  part of the transform).
* `get_mouse_pos` still divides by `ppu`.

Do not apply `ppu` in the callbacks *and* use the matrix: that doubles the scale.

### Snapping

At fractional scales a 1 logical px line aliases. Snap both rectangle edges in
physical space:

```odin
snap :: proc(v, ppu: f64) -> f64 { return math.round(v * ppu) / ppu }
```

`ui_scale_draw_rect` does this for `ui.draw_rect`. Raw `rl.*` rectangles are not
snapped; the demo exposes a toggle (`S`, `--no-snap`) to show the difference.

### When to keep a render target

A small 2D/3D world, a fixed virtual resolution, or a post-process pass still
needs its own target. Draw it into a small `LoadRenderTexture` and present it as
a texture inside the UI. Do not run `BeginMode3D` between the matrix push and
pop: `EndMode3D` resets the modelview that the matrix stack is using, and the UI
scale leaks and compounds (2x, 4x, 8x, off-screen). See
`references/scaling.md`.

### Scissor

`glScissor` is in framebuffer pixels, so `enable_scissors` converts the logical
rect by `ppu` and clamps it to the window:

```odin
px := round(x * ppu); py := round(y * ppu)
pw := round(w * ppu); ph := round(h * ppu)
rl.BeginScissorMode(clamp(px, 0, width), clamp(py, 0, height), ...)
```

Raylib flips Y against the active framebuffer height internally. With no render
target bound that height is the window, so pass top-left coordinates either way
and do not flip again. If the UI is drawn into a target, clamp to the target's
size instead of the window's.

### Mouse

```odin
if inside(window, mouse) {
    logical = mouse / ppu
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
  high `ppu` with a large atlas. This was a real crash in the starter.
* Set the atlas filter to `.BILINEAR`. With pixel-snapped quads, `.POINT` also
  works; `.BILINEAR` avoids hard edges.
* A per-size glyph cache means changing `ppu` creates new glyph sizes. That is
  normal; watch atlas growth, and quantize the pixel size if the zoom is smooth.

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
ui_scale_init(&app.scale, 1)      // ui_scale = 1, dpi_scale = 1
renderer_init(&app.renderer)
ui.init(CALLBACKS, 65536, 8 * mem.Megabyte)
app_init()                        // pages load their fonts through Context

for !rl.WindowShouldClose() {
    handle_input()

    rl.BeginDrawing()
    rl.ClearBackground(window_bg)
    ui_poll(app_draw)             // matrix + ui.frame/root scope + pop
    rl.EndDrawing()
}
```

Order matters for teardown: `app_deinit` (pages) before `ui.deinit`, then the
renderer and the window. There is no render target to release.

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
destination space and be consistent.

With the modelview approach, `ppu = ui_scale` is enough when the framebuffer
matches the window (the driver scales it). If the framebuffer is larger and you
want to use the extra pixels, set `dpi_scale = render / screen` and keep dividing
the mouse by `ppu`.

## Run the starter

```sh
git clone --recurse-submodules https://github.com/carabalonepaulo/ui-demo.git my-app
cd my-app
just run
```

If it was cloned without submodules:

```sh
git submodule update --init --recursive
just run
```

Without `just`:

```sh
git submodule update --init --recursive
odin run src -collection:ui=ui/ui
```

Headless check:

```sh
odin run src -collection:ui=ui/ui -- --screenshot out.png --view 2 --scale 1.5
```
