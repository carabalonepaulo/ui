# Scaling

The UI library works in logical units and never sees physical pixels. Scaling is
entirely a backend concern: choose how many physical pixels one logical unit
maps to, then make every draw call honour it.

There are two ways to do that:

| | Modelview transform (recommended) | Offscreen target |
| --- | --- | --- |
| Extra VRAM | none | `dest * render_scale` RGBA |
| Text | rasterized at the physical size | rasterized at the physical size, then resampled |
| `rl.Draw*` called directly by a component | transformed automatically | only if the component converts by hand |
| Recreate on resize | no | yes |
| Best for | zoom and DPI | supersampling, fixed virtual resolution, post effects |

Use the matrix by default. The offscreen target is still the right tool when you
need a resolution that is not the window's (a 3D viewport, a virtual resolution,
a blur pass), but it is not needed to scale the UI.

## Two independent factors

```text
ui_scale     logical -> screen size   (1 = 100%, 2 = everything twice as big)
dpi_scale    screen -> framebuffer    (1 on a normal display, 2 on Retina)
pixels_per_unit (ppu) = ui_scale * dpi_scale
logical_size = window_size / ppu
```

Unlike a supersampled target, `ui_scale` never changes a texture size here: it
only changes `ppu` and `logical_size`. One logical unit is exactly `ppu`
framebuffer pixels.

## Render pass

```odin
ui_scale_update(&app.scale, window_size)   // derives ppu and logical_size

push_matrix()
scale_by(ppu)
{
    ui.frame()
    ui.scope(logical_size)
    draw_app()
}
pop_matrix()
```

`ui.frame()` and the root scope stay in the same block: their deferred ends run
in reverse order there, before the matrix is popped. Deferred popups run inside
`end_frame`, so they are inside the transform too.

Nothing is allocated, so resizing and zooming every frame are free.

## The transform

Every `rl.Draw*` call inside the block is transformed: rectangles, textures,
circles, lines, rounded rectangles, rotated quads. This is what makes the
approach compatible with a component that calls the backend directly instead of
going through `ui.draw_rect` / `ui.draw_text`.

rlgl transforms vertices on submission (CPU-side, into the batch), so:

* the matrix does not flush the batch and does not change draw order;
* push/pop in the middle of a frame is cheap and safe;
* adjacent rectangles share their edge exactly, because both go through the same
  float transform (no per-shape rounding seams).

It does not make edges land on whole pixels: a 1 logical px line at `ppu = 1.5`
still spans 1.5 pixels. See *Pixel snapping* below.

## What the matrix cannot cover

Three things are not geometry and need explicit handling:

| Concern | Why | Handling |
| --- | --- | --- |
| Mouse input | comes from the OS | divide by `ppu` |
| Scissor | `glScissor` is in framebuffer pixels | convert to physical and clamp |
| Text | glyphs come from a bitmap atlas | disable the matrix, draw at `size * ppu` |

```odin
// mouse: window units -> logical
logical = window_pos / ppu
// return a far-away sentinel when the pointer is outside the window

// scissor: logical rect -> framebuffer pixels
px = round(x * ppu); py = round(y * ppu)
pw = round(w * ppu); ph = round(h * ppu)
clamp_to_window(px, py, pw, ph)
```

## Text at the physical size

Scaling glyph quads with the matrix magnifies a bitmap, so text is the one thing
that must opt out:

```odin
draw_text = proc(font: Font, text: string, x, y, size, spacing: f64, color: Color) {
    pop_matrix()
    defer push_matrix()
    backend_draw_text(font, text, x * ppu, y * ppu, size * ppu, spacing * ppu, color)
}
```

`measure_text` must use the same physical size and return logical units:

```odin
physical := backend_measure(font, text, font_size * ppu, spacing * ppu)
return physical / ppu
```

Never round the *logical* measurement; round only in physical space. Otherwise
layout and glyphs disagree by a fraction of a pixel and wrapping flickers near
the boundary.

`draw_rect` does not need special handling: the matrix applies it.

## Pixel snapping

At fractional scales a 1 logical px line lands on a fractional framebuffer edge
and aliases. Snap both edges of every rectangle in physical space, expressed back
in logical units:

```odin
snap :: proc(v, ppu: f64) -> f64 { return math.round(v * ppu) / ppu }

x0 := snap(x, ppu);          x1 := snap(x + w, ppu)
y0 := snap(y, ppu);          y1 := snap(y + h, ppu)
```

Snapping the two edges (not the origin and the size) keeps neighbours consistent:
every rectangle that touches a coordinate snaps it to the same place. Snapping
the origin and the size independently produces 1px seams at fractional scales.

Window MSAA (`MSAA_4X_HINT`) smooths what snapping cannot, at a fraction of the
memory of a supersampled target.

## Direct backend calls from components

The library converts scope-local positions to screen coordinates internally
(`to_screen_pos`), so a component that draws with the backend directly has to add
the origin itself:

```odin
origin := ui.get_screen_pos()          // logical, includes scroll offsets
rl.DrawTexturePro(tex, src, {f32(origin.x + x), f32(origin.y + y), w, h}, {}, 0, tint)
```

That is the only extra step. There is no `* ppu`: the matrix does the scaling.
Text drawn with a raw backend call instead of the text callback bypasses the
physical-size logic and will be blurry.

## 2D and 3D worlds

Do not run `BeginMode3D`/`EndMode3D` between the UI matrix push and pop. In
rlgl, a modelview `PushMatrix` redirects the "current matrix" to an internal
transform matrix, and `EndMode3D` calls `rlMatrixMode` + `LoadIdentity`, so the
matching pop restores the wrong matrix. The UI scale stays in the transform and
is applied again on the next frame: 2x, 4x, 8x, then everything is off-screen.
(Reproduced on raylib 6.0.)

Render the world into its own texture and present that texture as a UI element:

```odin
BeginTextureMode(world_target)      // small and fixed, e.g. 320x180
    ClearBackground(world_bg)
    BeginMode3D(camera)
        draw_world()
    EndMode3D()
EndTextureMode()

// inside the UI, under the matrix, from the component:
origin := ui.get_screen_pos()
src := rl.Rectangle{0, 0, f32(world_target.texture.width), -f32(world_target.texture.height)}
dst := rl.Rectangle{f32(origin.x), f32(origin.y), 320, 180}
rl.DrawTexturePro(world_target.texture, src, dst, {}, 0, rl.WHITE)
```

A 320x180 viewport costs about 230 KB, keeps its own aspect and depth buffer, and
does not care about the window size. The same applies to a 2D world.

## When the offscreen target is still right

* **Supersampling** (`render_scale > 1`): render bigger, then downsample.
  `texture = ceil(dest * render_scale)`, `logical = texture / ppu` with
  `ppu = ui_scale * render_scale`.
* **Fixed virtual resolution**: render a constant logical space and letterbox it.
  The target size follows the virtual resolution, not the window.
* **Post effects** on the whole UI (blur, distortion): the target is the input.

The matrix and the target are alternatives, not layers: applying `ppu` in the
callbacks *and* scaling with the matrix doubles the scale. Pick one per pass.

## High-DPI

Decide whether the destination, the mouse and the layout are in window units or
framebuffer units, and be consistent.

* `window_size` from the window API, mouse from the same API: `ppu = ui_scale`,
  and only the framebuffer differs (the driver scales it).
* If the framebuffer is larger than the window and you want to use the extra
  pixels: `ppu = ui_scale * (framebuffer / window)` and keep dividing the mouse
  by `ppu`.

## Cost

The matrix itself costs nothing: no allocation, no extra pass, no resize work.
The remaining GPU cost is the glyph atlas. A backend that rasterizes on demand
grows the atlas with every distinct glyph pixel size, so a smooth zoom slider
creates many sizes. Quantize the physical size (for example `round(size * ppu)`)
or reset the atlas when `ppu` changes by more than a few percent.

## Backend checklist

1. Derive `ppu` and `logical_size` every frame from the window.
2. Push the matrix before `ui.frame()` and pop it after the last deferred draw.
3. Convert `measure_text` to physical, return logical.
4. Drop the matrix around `draw_text`; rasterize at `size * ppu`.
5. Divide mouse positions by `ppu`; sentinel when outside.
6. Convert scissor rects to framebuffer pixels and clamp; flip once.
7. Snap rectangle edges in physical space.
8. Keep `rl.BeginMode3D` out of the matrix scope.
9. Do not mix the matrix with a supersampled target in the same pass.
10. Release the atlas and call `ui.deinit()` on shutdown.

For a complete implementation, see `ui-demo/src/scale.odin` and
`references/backends/raylib.md`.
