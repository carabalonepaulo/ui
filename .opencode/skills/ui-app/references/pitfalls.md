# Pitfalls, limitations, and fixed bugs

## Fixed in this repository

### `.Letter` wrapping had zero-width tokens

`get_token_cache` measured each glyph into a local but never assigned it to
`token.size`; `token.step` then used `token.size.x` (`0`). Every letter advanced
by `letter_spacing` only and wrapping never triggered.

Fixed in `ui/text.odin`:

```odin
if rune == ' ' {
    token.size = space_size
} else {
    token.size = ctx.callbacks.measure_text(...)
}
token.step = token.size.x + opts.letter_spacing
```

### Exact-fit and single-line overflow measured as width 0

`text`/`measure_text` only updated `max_width` when a token caused a wrap. A
single word wider than the container (and a line that exactly matched the
container, because the fast path used `<`) never wrapped, so the reported width
stayed 0.

Fixed by using `<=` for the fast path and including the final line's cursor:

```odin
if container.cursor.x > max_width do max_width = container.cursor.x
```

Both `text` and `measure_text` now report the clamped container width for an
overlong single line. If your project carries its own copy of `ui/text.odin`,
apply the same changes there.

## Design limitations

### Scopes and containers do not advance the parent cursor

`scope`, `scope_at`, `flex`, `stack`, `wrap`, `list`, and `grid` do not move the
parent cursor. `list`/`grid`/`wrap` own their internal layout. Two sibling
`scope` calls overlap at the same position unless wrapped in blocks with `next`
or placed with `scope_at`.

To get flow:

* `stack`/`flex`/`wrap` + `ui.next` for children,
* `scope_at` for regions,
* `padding`/`center` for groups,
* `flex` for distributing known space.

Auto-sized containers (`stack`, `center` with `AUTO`, `text` with `AUTO`) use the
previous frame's size and converge one frame late. Do not rely on zero-latency
reflow.

### Clip is also the hit-test rectangle

`begin_scope` computes `scope.clip = intersect(parent.clip, rect)` regardless of
the `.Clip` flag. Hit testing uses `clip`, so a child that draws outside its
parent's rect cannot be hovered there. There is no overflow-visible mode for
input. Render overlays/popups in the root coordinate space instead.

### `.Pressed` on culled scopes

`resolve_target` skips scopes with `!is_visible()` or no interests, so it does
not clear their flags. If an item is pressed and then scrolled out before its
state is consumed, the flag can stay true and fire when it returns. Consume
press state in the same frame the item is visible, or clear application state
when rows leave the viewport.

### Text tokenizer

The tokenizer splits on spaces (`.Word`) or runes (`.Letter`). It does not treat
`\n` as a line break. Split paragraphs into separate `text` calls if needed.

### Backend measure quirks

The token step is `measured_width + letter_spacing`. Some backends include a
trailing spacing when measuring a single character, so a space token can be
slightly wider than expected. This is cosmetic; fix it in the backend's
`measure_text` if exact metrics matter.

### `format_bytes` is not a bug

`format_bytes` assigns `context.allocator = get_temp_allocator()` inside the
procedure. In Odin, `context` is a value; the assignment affects callees made
from that procedure (which is the intent) and does not leak to the caller.

## Backend integration pitfalls

### `ui.deinit()` is mandatory

Releasing textures is not enough. `ui.deinit()` frees the scope buffers,
interest buffers, deferred queues, store, and frame arena. A backend that only
destroys its textures leaks the UI context.

### Do not put `any` values in deferred payloads

A popup (or any deferred callback) runs after the procedure that queued it
returns. An `any` holding a string typically points at a stack temporary for the
string header; the header is dead by the time the popup reads it. Store concrete
strings (`[3]string`) or allocate the payload on `ui.get_temp_allocator()`.

This is not hypothetical: it produced empty/garbage text in a cell tooltip.

### Batched backends need a flush before readback

If the backend batches draw calls, a screenshot/readback taken before the
end-of-frame flush sees an incomplete frame. Flush the batch before reading the
framebuffer. The raylib backend reference has the specific call.

### Texture updates need packed rows

If the backend updates a sub-rectangle of a texture, the pixel pointer usually
has to contain `rec.width * bytes_per_pixel` per row, not a slice of the full
texture. Build a packed staging buffer.

Do not allocate that staging buffer from the UI frame arena: a full-atlas upload
at high `pixels_per_unit` can be much larger than the arena (8 MB by default).
Use a reusable buffer owned by the backend.

### Downsampling an offscreen target

Only relevant if the pass renders into a target (supersampling, virtual
resolution, post effects). Linear filtering samples a 2x2 texel footprint, which
is a box filter at exactly 2x; larger or fractional factors need mipmaps +
trilinear, or a box-filter shader. `TRILINEAR` without generated mipmaps is just
bilinear. See `references/scaling.md`.

### Scissor coordinate systems

The UI passes top-left logical rectangles. `glScissor` is in framebuffer pixels
and is not affected by the modelview, so the backend must convert by `ppu` (or to
the target's pixel grid) and clamp. Some APIs use bottom-left scissor
coordinates; flip once against the current target height and do not flip twice.

### Font atlas scale

A glyph atlas must be rasterized at the physical size used to draw, that is
`font_size * pixels_per_unit`. A 2x atlas with a zoom of 2 is fine; the same
atlas with zoom 1.5 or 3 is not. A backend that rasterizes on demand handles this
naturally; a per-size atlas needs a cache keyed by the physical size. See
`references/backends/raylib.md`.

### Do not apply `ppu` twice

The matrix scales draw calls; the callbacks must not. If `draw_rect` multiplies
by `ppu` *and* the frame runs under a matrix, everything doubles. Choose one
place per pass: matrix in the callbacks, or matrix in the render pass, never
both.

### 3D blocks inside the UI matrix

Do not call `BeginMode3D`/`EndMode3D` between the UI matrix push and pop. rlgl's
modelview `PushMatrix` redirects the current matrix to an internal transform,
and `EndMode3D` calls `rlMatrixMode` + `LoadIdentity`; the matching pop then
restores the wrong matrix and the UI scale is applied again every frame (2x, 4x,
8x, off-screen). Render the world into its own texture and present it as a UI
element instead.

### High-DPI

Window coordinates and framebuffer coordinates can differ. Decide which one the
destination, mouse position, and layout use, and be consistent.
`pixels_per_unit = ui_scale * dpi_scale` lets you use the extra framebuffer
pixels while keeping layout in window units.

## Debugging checklist

1. Nothing draws: is `ui.frame()` called, is a root scope open, is the backend
   drawing into the right window/target, is the target bound, is the matrix
   scale non-zero (a `ppu` of 0 collapses everything)?
2. Wrong positions: are scopes siblings or nested? Did you forget a `{ ... }`
   block? Is the parent cursor still at the old position? Raw backend calls need
   `ui.get_screen_pos()`.
3. Text missing: does the font handle exist? Is the text's `Text_Options` the
   same as when measured? Is the atlas uploaded before drawing? Is the glyph
   outside the clip?
4. Text blurry: is the backend drawing at the physical size? Is the text
   callback scaling glyph quads with the matrix instead of disabling it? Is an
   offscreen target being upscaled?
5. Everything twice as big: is `ppu` applied in the callbacks and in the matrix
   at the same time?
6. Input dead: is the scope's `clip` non-empty? Does it have any `bind`? Is a
   child with interests on top? Is the mouse mapping in logical coordinates?
7. State resets: is the `ui.get` entry touched every frame? Did the id change?
8. Assert `ui buffer overflow`: raise the scope capacity passed to `ui.init`.
9. `odin check -vet` complains: the library currently has shadow/unused
   warnings. Use `odin build` for correctness; clean up warnings only if you are
   editing those files.
