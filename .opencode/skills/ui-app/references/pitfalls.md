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
overlong single line. If you maintain a vendored copy of `ui/text.odin`, apply
the same two changes there.

## Design limitations

### Scopes and containers do not advance the parent cursor

`scope`, `scope_at`, `flex`, `stack`, `wrap`, `list`, and `grid` do not move the
parent cursor. `list`/`grid`/`wrap` own their internal layout. Consequence:
two sibling `scope` calls overlap at the same position unless wrapped in blocks
with `next` or placed with `scope_at`.

If you want flow:

* `stack`/`flex`/`wrap` + `ui.next` for children,
* `scope_at` for regions,
* `padding`/`center` for groups.

Auto-sized containers (`stack`, `center` with `AUTO`, `text` with `AUTO`) use the
previous frame's size and converge one frame late. Do not rely on zero-latency
reflow.

### Clip is also the hit-test rectangle

`begin_scope` computes `scope.clip = intersect(parent.clip, rect)` regardless of
the `.Clip` flag. Hit testing uses `clip`, so a child that draws outside its
parent's rect cannot be hovered there. There is no `overflow: visible` mode for
input. Render popups in the root coordinate space instead.

### `.Pressed` on culled scopes

`resolve_target` skips scopes with `!is_visible()` or no interests, so it does
not clear their flags. If an item is pressed and then scrolled out before its
state is consumed, the flag can stay true and fire when it returns. Consume
press state in the same frame the item is visible, or clear application state
when rows leave the viewport.

### Text tokenizer

The repository's tokenizer splits on spaces (`.Word`) or runes (`.Letter`). It
does not treat `\n` as a line break. A newer vendored copy (for example
`maze-puzzle/deps/ui/text.odin`) does; do not assume the repository version and
the vendored version are identical. Split paragraphs into separate `text` calls
if needed.

### Letter spacing and backend measure quirks

The token step is `measured_width + letter_spacing`. Raylib's `MeasureTextEx`
already includes one trailing spacing for a single character, so a space token
can be slightly wider than expected. This is cosmetic; use a fontstash backend
if you need exact metrics.

### Formatting is not a bug

`format_bytes` assigns `context.allocator = get_temp_allocator()` inside the
procedure. In Odin, `context` is a value; the assignment affects callees made
from that procedure (which is the intent) and does not leak to the caller. Do
not "fix" it by restoring the allocator.

## Backend pitfalls

### `ui.deinit()` is mandatory

Unloading the render texture is not enough. `ui.deinit()` frees the scope
buffers, interest buffers, deferred queues, store, and arena. The attached
`maze-puzzle/src/ui.odin` originally only unloaded the texture and leaked
everything else.

### Do not put `any` values in deferred payloads

A popup runs after the procedure that queued it returns. An `any` holding a
string typically points at a stack temporary for the string header; the header
is dead by the time the popup reads it. This produced empty/garbage text in
`maze-puzzle`'s cell popup. Store concrete strings (`[3]string`) or allocate the
payload on `ui.get_temp_allocator()`.

### Draw before/after the batch

Raylib batches draw calls. A screenshot/readback taken between the UI blit and
`EndDrawing` sees a black frame. Flush with `rlgl.DrawRenderBatchActive()`
before `LoadImageFromScreen`/readback. `TakeScreenshot` also flushes internally
because it is called from `EndDrawing`; calling it yourself before
`EndDrawing` still needs a flush.

`TakeScreenshot` prepends the working directory and explicitly documents that
the filename must not contain a path. For arbitrary paths use
`LoadImageFromScreen` + `ExportImage`.

### `UpdateTextureRec` takes packed rows

The pixel pointer must contain `rec.width * bytes_per_pixel` per row, not a
sub-rect of a larger buffer. Build a temporary tightly packed buffer (the demo
does) or update the whole texture.

Do not allocate that staging buffer from the UI frame arena: a full-atlas upload
at high supersampling can be much larger than the arena (typically 8 MB). Use a
reusable heap buffer owned by the renderer. This was a real crash in the demo at
`scale 4, ssaa 4`.

### `TRILINEAR` without mipmaps is bilinear

`SetTextureFilter(.TRILINEAR)` only uses mipmaps if they exist. Generate them
after drawing (`GenTextureMipmaps`) or use `.BILINEAR`. For exactly 2x,
bilinear is already a 2x2 box filter; for 3x/4x, generate mipmaps or use a
downsample shader.

### Scissor Y in a render texture

Raylib 5.5/6.0 flips scissor Y against `CORE.Window.currentFbo.height` when an
FBO is active. Pass top-left coordinates in target pixels. Flipping again clips
the wrong rows.

### Font atlas scale

The glyph atlas must be rasterized at the physical size used to draw. A 2x
atlas with a camera zoom of 2 is fine; the same atlas with zoom 1.5 or 3 is not.
Fontstash handles this naturally because it rasterizes on demand; raylib font
atlases need a cache keyed by `ppu` (see the `maze-puzzle` patch).

### High-DPI

`GetScreenWidth/Height` are window coordinates; `GetRenderWidth/Height` can be
the physical framebuffer. Mouse positions are in screen coordinates. Pick one
destination space and be consistent. `render_scale = DPI scale` is a simple way
to get a physical-resolution texture while keeping screen-coordinate layout.

## Debugging checklist

1. Nothing draws: is `ui.frame()` called, is a root scope open, is the backend
   drawing into the right target, is the render texture bound?
2. Wrong positions: are scopes siblings or nested? Did you forget a `{ ... }`
   block? Is the parent cursor still at the old position?
3. Text missing: does the font handle exist? Is the text's `Text_Options` the
   same as when measured? Is the atlas uploaded before drawing? Is the glyph
   outside the clip?
4. Text blurry: is the backend drawing at the physical size? Is the final blit
   upscaling?
5. Input dead: is the scope's `clip` non-empty? Does it have any `bind`? Is a
   child with interests on top? Is the mouse mapping in logical coordinates?
6. State resets: is the `ui.get` entry touched every frame? Did the id change?
7. Assert `ui buffer overflow`: raise the scope capacity passed to `ui.init`.
8. `odin check -vet` complains: the library currently has shadow/unused
   warnings. Use `odin build` for correctness; clean up warnings only if you are
   editing those files.
