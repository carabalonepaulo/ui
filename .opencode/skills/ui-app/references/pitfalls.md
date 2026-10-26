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

Releasing the render target is not enough. `ui.deinit()` frees the scope
buffers, interest buffers, deferred queues, store, and frame arena. A backend
that only destroys its target leaks the UI context.

### Do not put `any` values in deferred payloads

A popup (or any deferred callback) runs after the procedure that queued it
returns. An `any` holding a string typically points at a stack temporary for the
string header; the header is dead by the time the popup reads it. Store concrete
strings (`[3]string`) or allocate the payload on `ui.get_temp_allocator()`.

This is not hypothetical: it produced empty/garbage text in a cell tooltip.

### Batched backends need a flush before readback

If the backend batches draw calls, a screenshot/readback taken between the UI
blit and the end-of-frame flush sees an incomplete frame. Flush the batch before
reading the framebuffer. The raylib backend reference has the specific call.

### Texture updates need packed rows

If the backend updates a sub-rectangle of a texture, the pixel pointer usually
has to contain `rec.width * bytes_per_pixel` per row, not a slice of the full
texture. Build a packed staging buffer.

Do not allocate that staging buffer from the UI frame arena: a full-atlas upload
at high supersampling can be much larger than the arena (8 MB by default). Use a
reusable buffer owned by the backend.

### Filtering and mipmaps

Linear filtering only samples a 2x2 texel footprint. For exactly 2x
downsampling that is a box filter; for 3x/4x or fractional scaling it
undersamples. Generate mipmaps and use trilinear filtering for larger
downscales, or use a box-filter shader. `TRILINEAR` without generated mipmaps is
just bilinear. See `references/scaling.md`.

### Scissor coordinate systems

The UI passes top-left logical rectangles. The backend must convert them to its
framebuffer convention. Some APIs use bottom-left scissor coordinates; flip once
against the current target height and do not flip twice. Clamp the rect to the
target.

### Font atlas scale

A glyph atlas must be rasterized at the physical size used to draw. A 2x atlas
with a camera zoom of 2 is fine; the same atlas with zoom 1.5 or 3 is not. A
backend that rasterizes on demand handles this naturally; a per-size atlas needs
a cache keyed by `pixels_per_unit`. See `references/backends/raylib.md`.

### High-DPI

Window coordinates and framebuffer coordinates can differ. Decide which one the
destination rectangle, mouse position, and layout use, and be consistent.
`render_scale = DPI scale` is a simple way to get a physical-resolution target
while keeping screen-coordinate layout.

## Debugging checklist

1. Nothing draws: is `ui.frame()` called, is a root scope open, is the backend
   drawing into the right target, is the target bound?
2. Wrong positions: are scopes siblings or nested? Did you forget a `{ ... }`
   block? Is the parent cursor still at the old position?
3. Text missing: does the font handle exist? Is the text's `Text_Options` the
   same as when measured? Is the atlas uploaded before drawing? Is the glyph
   outside the clip?
4. Text blurry: is the backend drawing at the physical size? Is the present
   upscaling the target?
5. Input dead: is the scope's `clip` non-empty? Does it have any `bind`? Is a
   child with interests on top? Is the mouse mapping in logical coordinates?
6. State resets: is the `ui.get` entry touched every frame? Did the id change?
7. Assert `ui buffer overflow`: raise the scope capacity passed to `ui.init`.
8. `odin check -vet` complains: the library currently has shadow/unused
   warnings. Use `odin build` for correctness; clean up warnings only if you are
   editing those files.
