# Scaling

The UI library works in logical units. Scaling is entirely a backend concern:
pick a destination rectangle on the window, render the logical tree into an
offscreen target at a physical resolution, then present that target. The
library never needs to know about DPI, cameras, or texture sizes.

## Two independent factors

```text
ui_scale       logical -> screen size  (1 = 100%, 2 = everything twice as big)
render_scale   supersampling factor    (1 = none, 2 = render at 2x then downscale)
pixels_per_unit (ppu) = ui_scale * render_scale
```

For a destination of `dest_size` (window/screen units):

```text
texture_size = ceil(dest_size * render_scale)
logical_size = texture_size / ppu
```

This mapping is exact: one logical unit is `ppu` physical texels, and the
texture covers the whole logical space. The final present stretches the texture
to `dest_size`; that stretch is by `render_scale` only, not by `ui_scale`.

Why not `logical_size = dest_size / ui_scale` and `texture = logical * ppu`?
Truncating the texture to integers and re-deriving the logical size introduces
sub-texel mismatches. Deriving the logical size from the integer texture keeps
the mapping exact; the destination is stretched by at most one texel.

`ui_scale` alone does not change the texture size (texture = dest *
render_scale); it changes `ppu` and `logical_size`. `render_scale` changes both
the texture size and `ppu`.

## Render pass

```odin
begin_offscreen_target(target)

{
    ui.frame()
    ui.scope(logical_size)
    draw_app()
}

end_offscreen_target()
present(target, dest_rect)
```

`ui.frame()` and the root scope must be inside the same block: their deferred
ends run in reverse order there, while the target is still bound. Deferred
popups run in `end_frame`, so they must also be inside the target pass.

The target should be cleared before drawing. If the UI root covers every texel,
a transparent clear is fine; otherwise clear to the app background.

## Transform callbacks, not a camera

The cleanest backend transforms coordinates in the draw callbacks and uses no
camera:

```odin
draw_rect = proc(x, y, w, h: f64, color: Color) {
    ppu := current_ppu
    x0 := round(x * ppu)
    y0 := round(y * ppu)
    x1 := round((x + w) * ppu)
    y1 := round((y + h) * ppu)
    if x1 <= x0 || y1 <= y0 do return
    backend_fill_rect(x0, y0, x1 - x0, y1 - y0, color)
}
```

Round both edges in **physical** space. Flooring the origin and ceiling the
size in logical space (or before scaling) grows every rectangle by up to one
texel and creates seams at fractional scales.

A camera can scale rectangles, but it does not solve text: glyphs rasterized at
a logical size are then magnified by the camera and blur. If you use a camera,
the glyph atlas must be pre-baked at the same zoom, and changing the zoom
requires reloading fonts.

## Text at the physical size

`ui.Callbacks.measure_text` and `draw_text` receive logical sizes. The backend
must convert them:

```odin
// measure: measure at physical size, then return logical units
physical := backend_measure(font, text, font_size * ppu, spacing * ppu)
return physical / ppu

// draw: rasterize/draw at physical size
backend_draw_text(font, text, x * ppu, y * ppu,
                  font_size * ppu, spacing * ppu, color)
```

A backend with a per-size font atlas must key that atlas by the physical size
(`font_size * ppu`). A backend that rasterizes on demand can keep one handle per
face and ignore the size; see the raylib backend reference.

`measure_text` must use the same physical size as `draw_text`, otherwise layout
and glyphs disagree by a scale factor.

## Mouse mapping

Map from destination/window space into logical space:

```text
logical.x = (mouse.x - dest.x) / dest.w * logical_size.x
logical.y = (mouse.y - dest.y) / dest.h * logical_size.y
```

Return a far-away sentinel when the pointer is outside the destination
rectangle. The UI hit-tests against integer logical clip rects.

If the backend uses a high-DPI framebuffer, decide whether mouse coordinates and
the destination are in window units or physical units and be consistent.

## Scissor mapping

`enable_scissors(x, y, w, h: i32)` receives a logical clip rect. Convert it to
physical texels:

```text
px = round(x * ppu)
py = round(y * ppu)
pw = round(w * ppu)
ph = round(h * ppu)
```

Clamp to the target bounds. Some backends address the framebuffer bottom-up, so
their scissor Y must be flipped relative to the target height; do it once, in
the backend, and pass top-left coordinates from the UI. Do not flip twice.

`disable_scissors` should only end the scissor pass that `enable_scissors`
started.

## Downsampling

When `render_scale > 1`, the target is larger than the destination.

* **Exactly 2x, bilinear.** An output pixel maps to a 2x2 texel footprint; a
  linear sample at the pixel centre averages those four texels. This is a box
  filter and is the cheapest good default.
* **3x/4x, or fractional.** Linear sampling only reads a 2x2 block out of a
  larger footprint and aliases. Generate mipmaps and use trilinear filtering, or
  use a box-filter/downsample shader.
* **1x.** Use bilinear (or point if the mapping is exactly 1:1 and you snap
  every glyph).
* **Upscaling** (texture smaller than destination) always loses quality; make
  sure `texture_size >= dest_size`. This is what `render_scale >= 1` guarantees.

Mipmap generation every frame costs GPU time and may log (backend-dependent).
Only generate when needed, or replace it with a downsample shader.

## Target lifecycle

Recreate the target when:

* the destination size changes,
* `render_scale` changes the integer texture size,
* the target does not exist yet,
* the graphics device was reset.

`ui_scale` alone does not require a new texture (unless the derived integer size
changes). Always update `ppu` and `logical_size`, even when reusing the target.

Clamp inputs: `ui_scale` in `[0.25, 8]`, `render_scale` in `[1, 4]`. Guard
against zero-sized/minimized windows. Unload the target on shutdown and call
`ui.deinit()` for the UI context.

## Transparency

A transparent target plus the default alpha blend produces dark fringes where
opaque and transparent texels are sampled together unless the source is
premultiplied. Either cover the whole target with an opaque root (normal app
UI), or use premultiplied alpha for overlays.

## Cost

`render_scale = 2` at 1920x1080 allocates a 3840x2160 RGBA target (about 33 MB
on the GPU) and optionally a mip chain. At 4K it is 7680x4320 (about 133 MB).
Measure before shipping. Options:

* `render_scale = 1` with a larger `ui_scale` (text is rasterized at the
  physical size, so it stays sharp; SSAA mainly helps geometry edges).
* `render_scale = 1.5` with bilinear.
* A downsample shader instead of mipmaps.
* Reuse the target and regenerate mips only when the UI changes.

## Backend checklist

1. Convert `draw_rect`, `draw_text`, and `measure_text` with `ppu`.
2. Round edges/sizes in physical space.
3. Rasterize text at `size * ppu`.
4. Map mouse positions back to logical space.
5. Convert scissor rects to physical texels and clamp.
6. Size the target as `ceil(dest * render_scale)`.
7. Present with the correct vertical orientation.
8. Use mipmaps or a box filter for large downscale factors.
9. Recreate the target on resize/scale changes.
10. Call `ui.deinit()` and release backend resources.

For a complete implementation, see `ui-demo/src/scale.odin` and
`references/backends/raylib.md`.
