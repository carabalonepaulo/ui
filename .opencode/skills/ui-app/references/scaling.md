# Scaling and the raylib/fontstash backend

The UI library has no concept of a screen, a window, DPI, or a camera. It only
knows logical units. Scaling belongs to the backend, and the canonical
implementation is `demo/scale.odin`.

## Two independent factors

```text
ui_scale       logical -> screen size  (1 = 100%, 2 = everything twice as big)
render_scale   supersampling factor    (1 = no SSAA, 2 = render at 2x then downscale)
pixels_per_unit (ppu) = ui_scale * render_scale
```

At a window size `dest_size`:

```text
texture_size = ceil(dest_size * render_scale)
logical_size = texture_size / ppu        // the UI coordinate space
```

This makes the mapping exact: one logical unit is `ppu` physical texels, and the
texture covers the whole logical space. The final blit stretches the texture to
`dest_size`; that stretch is by `render_scale` only, not by `ui_scale`.

Why not `logical_size = dest_size / ui_scale` and `tex = logical * ppu`? Because
truncating `tex` to an integer then re-deriving logical gives sub-texel
mismatches. Deriving logical from the integer texture keeps the mapping exact.
The destination is stretched by at most one texel.

## The render pass

```odin
ui_scale_begin(&app.scale)
{
    ui.frame()
    ui.scope(app.scale.logical_size)
    app_draw()
}
ui_scale_end(&app.scale)
```

`ui.frame()` and the root scope must be inside the same block: their deferred
ends run in reverse order there, before the render target is unbound. Popups
drawn by `end_frame` are also inside the texture.

`ui_scale_begin`:

```odin
rl.BeginTextureMode(s.target)
rl.ClearBackground(rl.BLANK)     // root fill usually covers everything
s.active = true
```

`ui_scale_end`:

```odin
s.active = false
rl.EndTextureMode()

if s.render_scale > 2 {
    rl.GenTextureMipmaps(&s.target.texture)
    rl.SetTextureFilter(s.target.texture, .TRILINEAR)
} else {
    rl.SetTextureFilter(s.target.texture, .BILINEAR)
}

source := rl.Rectangle{0, 0,
    f32(s.target.texture.width),
    -f32(s.target.texture.height)}   // render textures are vertically flipped

dest := rl.Rectangle{f32(dest_pos.x), f32(dest_pos.y),
                     f32(dest_size.x), f32(dest_size.y)}

rl.DrawTexturePro(s.target.texture, source, dest, {0, 0}, 0, rl.WHITE)
```

At exactly 2x, GL_LINEAR samples a 2x2 texel footprint, which is a box filter;
that is why `render_scale == 2` is the cheapest good default. Above 2x, the
2x2 footprint undersamples the supersampled image; mipmaps (or a box-filter
shader) are required. `TRILINEAR` without generated mipmaps is just bilinear.

Raylib's `GenTextureMipmaps` logs at INFO every call. Either accept the log
spam or raise the trace level after init (`rl.SetTraceLogLevel(.WARNING)` in the
demo).

## Transform callbacks, not the camera

The attached `maze-puzzle` code used `Camera2D{zoom = scale * render_scale}`.
That works for rectangle geometry but has two problems:

1. `draw_rect` rounds/floors coordinates in **logical** space before the camera
   scales them. At a fractional `ui_scale`, edges land on fractional texels and
   blur.
2. `DrawTextEx` rasterizes glyphs at the logical font size, then the camera
   magnifies them. The glyph atlas must be pre-baked at the zoom factor or the
   text blurs.

The robust approach is to transform in the callbacks and never use a camera:

```odin
draw_rect = proc(x, y, w, h: f64, color: ui.Color) {
    ppu := app.scale.ppu
    x0 := i32(math.round(x * ppu))
    y0 := i32(math.round(y * ppu))
    x1 := i32(math.round((x + w) * ppu))
    y1 := i32(math.round((y + h) * ppu))
    if x1 <= x0 || y1 <= y0 do return
    rl.DrawRectangle(x0, y0, x1 - x0, y1 - y0, transmute(rl.Color)(color))
}

draw_text = proc(font, text, x, y, size, spacing: f64, color: ui.Color) {
    ppu := app.scale.ppu
    renderer_draw_text(&app.renderer, font, text,
                       x * ppu, y * ppu, size * ppu, spacing * ppu, color)
}
```

Round both edges in physical space. Do not floor the origin and ceil the size;
that grows every rectangle by up to one texel and creates seams.

## Mouse mapping

```odin
ui.Vec2{
    (mouse.x - dest_pos.x) / dest_size.x * logical_size.x,
    (mouse.y - dest_pos.y) / dest_size.y * logical_size.y,
}
```

Return a far-away sentinel when the cursor is outside the destination rectangle.
The UI's hit test compares against integer logical clip rects.

## Scissor

Scissor rectangles are in physical texels:

```odin
px := i32(math.round(f64(x) * ppu))
py := i32(math.round(f64(y) * ppu))
pw := i32(math.round(f64(w) * ppu))
ph := i32(math.round(f64(h) * ppu))

// clamp to the target
pw = clamp(pw, 0, tw - px)
ph = clamp(ph, 0, th - py)

rl.BeginScissorMode(px, py, pw, ph)
```

Raylib 5.5+ flips the Y coordinate against `CORE.Window.currentFbo.height` when
rendering into a render texture. Pass top-left coordinates; do **not** flip Y
yourself. (Older code sometimes flipped twice and clipped the wrong rows.)

`disable_scissors` should call `rl.EndScissorMode` only when the target is
active.

## Text with fontstash

Fontstash rasterizes glyphs at the requested size into a single-channel atlas.
Raylib's default shader expects RGBA, so mirror the dirty region into white RGB
+ glyph alpha:

```odin
if fontstash.ValidateTexture(&r.fs, &dirty) {
    // Expand dirty rect into a tightly packed RGBA buffer.
    // Row stride must be dw * 4 for UpdateTextureRec.
    rl.UpdateTextureRec(r.atlas, {x, y, dw, dh}, raw_data(pixels))
}
```

Crucial rules:

* Set fontstash's size to `font_size * ppu`, not `font_size`. That is what makes
  text crisp at any scale.
* Set `align_vertical = .TOP` if the UI's `y` is the top of the text box
  (raylib's `DrawTextEx` semantics). With `.TOPLEFT`, fontstash offsets the
  baseline by the ascender.
* Measure with the same physical size and divide by `ppu` to return logical
  units to the UI.
* The atlas texture must be uploaded **before** drawing the quads that reference
  new glyphs. The demo collects quads, flushes the atlas, then draws.
* If fontstash grows the atlas mid-string, normalized UVs change. The demo
  retries the whole string after a size change; glyphs are cached, so the retry
  is cheap.
* Set the atlas filter to `.BILINEAR` (or `.POINT` if you snap every glyph).
* A font atlas is a cache keyed by font + pixel size. Changing `ui_scale`
  generates a new set of glyph sizes.
* Do not allocate the staging buffer for a dirty-rect upload from the UI frame
  arena. A full-atlas update at high `render_scale` can be tens of megabytes and
  exceed the 8 MB arena; keep a reusable heap buffer on the renderer (the demo
  does this).

`demo/renderer.odin` is the complete implementation: RGBA mirror, dirty-rect
upload, growth handling, measure, and draw.

## Text with raylib fonts

If you use raylib's own font atlas instead of fontstash:

```odin
font := rl.LoadFontEx(path, i32(size * ppu), codepoints, count)
...
rl.DrawTextEx(font, cstr, {x * ppu, y * ppu}, size * ppu, spacing * ppu, color)
```

The atlas must be loaded at `size * ppu`. If `ppu` changes, reload the font (or
key the font cache by `ppu`). The `maze-puzzle` patch does exactly that with a
`fonts.pixel_scale` global set by the UI backend and includes the scale in the
font cache key.

Do **not** load a 2x atlas and then draw through a camera at a different
magnification; sampling the atlas at a non-1:1 ratio blurs or aliases.

## Target lifecycle

Recreate the render texture when any of these change:

* destination size (window resize),
* `render_scale` (texture size),
* the target is missing.

`ui_scale` alone does not change the texture size (texture = dest *
render_scale); it changes `ppu` and `logical_size`. Always update both even when
the texture is not recreated.

Clamp inputs: `ui_scale` in `[0.25, 8]`, `render_scale` in `[1, 4]`. Guard
against zero-sized windows (minimized).

Unload the target in the backend shutdown, and call `ui.deinit()` there too.
The attached code forgot `ui.deinit()` and leaked the context, store, queues, and
frame arena.

## High-DPI

Raylib's `GetScreenWidth/Height` are window (screen) coordinates;
`GetRenderWidth/Height` can be larger on high-DPI. If you enable
`FLAG_WINDOW_HIGHDPI`, either:

* treat the render size as the destination and convert mouse coordinates with
  the DPI scale, or
* keep the destination in screen coordinates and set `render_scale` to the DPI
  scale so the texture matches the physical framebuffer.

Mouse coordinates from raylib are in screen space; do not multiply them by DPI.

## Transparency and fringes

`ClearBackground(BLANK)` leaves the texture transparent. If the root does not
cover every texel (a UI overlay over a game), the final blit blends the texture
over whatever is already on screen. Bilinear sampling between opaque and
transparent pixels produces dark fringes because the RGB is not premultiplied.
Either cover the root or use premultiplied alpha and
`BLEND_ALPHA_PREMULTIPLY`.

## Cost

`render_scale = 2` at 1920x1080 allocates 3840x2160 RGBA (about 33 MB on the
GPU) and mipmaps it every frame if enabled. At 4K it is 7680x4320 (about 133 MB).
Measure before shipping. Options:

* `render_scale = 1` and a larger `ui_scale` (text is rasterized at physical
  size, so it stays sharp; SSAA only helps geometry edges).
* `render_scale = 1.5` with bilinear.
* A 4-tap box downsample shader at the final blit instead of mipmaps.
* Reuse the target across frames and only regenerate mipmaps when the UI
  actually changed.

## Common symptoms

| Symptom | Cause |
| --- | --- |
| Text is crisp at 1x, blurry at 1.5x | Glyphs rasterized at logical size, then camera-scaled. Rasterize at `size * ppu`. |
| Thin lines shift or vanish | Rounding in logical space. Round both edges in physical space. |
| Clip is offset vertically | Y flipped twice (or not at all) for FBO scissors. |
| UI looks soft at 2x | `TRILINEAR` without generated mipmaps; or the final blit is upscaling because `tex < dest`. |
| Text has dark halos | Atlas RGBA mirror set RGB=0 around glyphs, or unpremultiplied blending. Use RGB=255 + alpha. |
| Fonts pop/blur after changing scale | Font atlas cache not keyed by `ppu`. |
| Second frame flashes | One-frame `fit`/`center` lag, or glyphs drawn before the atlas upload. Flush before drawing. |
