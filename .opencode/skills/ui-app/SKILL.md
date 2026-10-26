---
name: Odin UI
description: Build apps, tools, and game overlays with the immediate-mode UI library in this repository. Use for layout (scopes, flex, stack, wrap, grid, list), cached text, input interests, the hashed store, popups, a raylib + fontstash backend, and supersampled/HiDPI scaling.
---

# Odin UI

This repository is the library, not an application. A package named `ui` lives in
`ui/` and has no dependency outside Odin's `core`. The reference application is
`demo/` (raylib + fontstash + scaling); use it as the working example before
inventing a new integration. Paths such as `ui/` and `demo/` are relative to the
repository root, not to this skill directory.

| Path | Purpose |
| --- | --- |
| `ui/` | The library package (`import ui "../ui"` or `import "ui:ui"`). |
| `test/` | Original scratch demo. Useful for unusual APIs, but less organised than `demo/`. |
| `demo/main.odin` | Window, callbacks, backend lifecycle, frame loop. |
| `demo/scale.odin` | Render-to-texture + supersampled scaling. |
| `demo/renderer.odin` | Fontstash atlas and text rendering. |
| `demo/app.odin` | App shell, navigation, cards, text, scaling inspector. |

Read `references/api.md` for signatures, `references/patterns.md` for recipes,
`references/scaling.md` for the scaling technique, and `references/pitfalls.md`
before debugging layout or input. The demo is the source of truth for a working
backend.

## Core model

* Immediate mode. One function builds the whole frame; there is no retained
  widget tree and no style system.
* All coordinates and sizes are `f64` **logical** units. The backend converts
  logical units to physical pixels.
* A `Scope` is an axis-aligned rectangle with a cursor. `begin_scope` places it
  at the parent's cursor. It does **not** advance the parent's cursor.
* A frame is a root scope containing every other scope. `ui.frame()` resets the
  scope buffer, executes deferred popups, resolves input, evicts unused state,
  and frees the frame arena.
* State lives in a hashed store keyed by `ui.Id`. Entries not touched in a frame
  are evicted. Allocate per-frame strings with `ui.get_temp_allocator()`.
* Input is injected by the backend through `Callbacks` and resolved at
  `end_frame`. Flags read while drawing are therefore one frame behind the
  event that produced them.

## Minimum frame

```odin
assert(ui.init(CALLBACKS, 65_536, 8 * mem.Megabyte))
defer ui.deinit()

for !rl.WindowShouldClose() {
    rl.BeginDrawing()
    defer rl.EndDrawing()

    // Keep frame() and the root scope in the same block. Their deferred ends
    // run in reverse order at the end of the block.
    {
        ui.frame()
        ui.scope(root_size)
        draw_app()
    }
}
```

For a scaled backend, put `frame/scope` inside the render-target block; see
`references/scaling.md`.

## Golden rules

1. **Know the size.** The library will not measure a flexible container for you.
   Use `ui.measure_*`, `ui.get_available_size()`, or an explicit design grid.
2. **Scopes do not flow.** `scope`, `scope_at`, `flex`, `stack`, `wrap`, `list`,
   and `grid` do not advance the parent cursor. Use `ui.next(&stack/flex/wrap,
   size)` to flow items, `scope_at` for absolute positions, or `padding` /
   `center` to place a group.
3. **Blocks control lifetimes.** Deferred functions end with the enclosing
   block. Use `{ ... }` for sibling scopes inside one procedure.
4. **Ids are identity.** Every stateful thing, text cache, scroll offset, and
   fit size needs a stable, unique `ui.Id`. Include the item index in ids.
5. **Touch state every frame.** `ui.get` returns a pointer for the frame; an
   entry not fetched in a frame is evicted at the end of it.
6. **Bind on the scope that owns the interaction.** `bind(.Hovered, &value)` is
   checked against the scope's clipped rectangle. Use `.Pass_Through` when a
   child and its parent should both receive the same interest.
7. **Clip is also hit-testing.** `Clip` restricts drawing and hit-testing to the
   scope's rectangle; overflow-visible hit areas are not supported.
8. **Measure text; do not guess.** Use `ui.measure_text` with exactly the same
   `Text_Options` used to draw. `text` and `measure_text` share a cache keyed by
   string + font + size + spacing + line spacing.
9. **Backend text scale.** Fontstash must rasterize at `font_size *
   pixels_per_unit`; raylib fonts must have an atlas at that size. Drawing
   logical-size glyphs through a camera zoom gives blurry text.
10. **Deferred payloads must not point at stack temporaries.** Do not put `any`
    values in a `Popup` payload; store concrete strings or allocate on
    `ui.get_temp_allocator()`.

## Layout building blocks

```odin
// Absolute placement.
ui.scope_at({x, y}, {w, h})   // ends at the end of the block

// Explicit flow with known item sizes.
s := ui.stack(ui.id("stack"), .Y, gap)
if ui.next(&s, {w, 24}) { ... }

// Row/column distribution.
f := ui.flex(size, .X, {{.Absolute, 200}, {.Flex, 1}, {.Flex, 2}}, gap = 12)
if ui.next(&f) { ... }

// Wrapping fixed-size items.
w := ui.wrap(ui.id("wrap"), size, {8, 8}, {12, 12, 12, 12})
if ui.next(&w, {80, 32}) { ... }

// Virtualized, scrollable collections.
ui.list_with_poly(&offset, size, count, item_height, gap, ud, item)
ui.grid_with_poly(&offset, size, count, {w, h}, {gx, gy}, ud, item, {.Clip})
```

`flex` distributes `remaining = size - gaps - absolute` between `.Flex` items by
weight. `stack` auto-fits its children (previous frame's size on the first
frame). `wrap` advances the parent's cursor in Y. `list` and `grid` own their
scroll offset and content size.

## Text

```odin
opts := ui.Text_Options {
    font           = my_font,
    font_size      = 16,
    font_color     = {230, 230, 230, 255},
    wrap           = .Word,   // .None, .Word, .Letter
    scroll         = .Y,      // only inside a fixed-size, clipped scope
    letter_spacing = 0,
    line_spacing   = 4,
}

// Measure once for buttons/labels.
size := ui.measure_text(ui.id("label"), {ui.AUTO, ui.AUTO}, "Save", &opts)
ui.scope_at({x, y}, size)
ui.text(ui.id("label"), size, "Save", opts)

// Fixed box with wrapping + clipping (scroll binds its own offset).
ui.scope({200, 120}, {.Clip})
ui.text(ui.id("body"), ui.get_size(), paragraph, opts_with_wrap_and_scroll, {.Clip})
```

`text` uses a fast path when the measured text fits (or `wrap == .None`). It
draws glyphs one token at a time; `opts.font` must be a handle the backend
understands. The repository's tokenizer splits on spaces only: `\n` is not a
line break. Use separate `text` calls or a newer vendored copy with newline
support.

## Input

```odin
hovered := ui.get(ui.id("button/hover"), bool)
pressed := ui.get(ui.id("button/pressed"), bool)

ui.scope_at(pos, size)
ui.bind(.Hovered, hovered)
ui.bind(.Pressed, pressed)

if hovered^ do ui.fill_rect(hover_color)
if pressed^ do ui.fill_rect(pressed_color)
```

Available interests: `.Hovered`, `.Pressed`, `.Pressed_Out`, `.Released`,
`.Released_Out`, `.Scroll_X`, `.Scroll_Y`. The backend resolves only the left
mouse button and the wheel; keyboard callbacks exist in `Callbacks` but the
current library does not call them. Query your backend (raylib) for keys.

`Pressed` is true for one frame, one frame after the actual press. Use
`.Released` for click completion if you need release semantics. For scroll, bind
`.Scroll_Y` to a stable `f64` on a clipped scope; the library clamps it at
`end_scope`.

## Store and IDs

```odin
current := ui.get(ui.id("nav/current"), int, 0)
state, just_created := ui.get(
    ui.id("cards"),
    []Card,
    destroy = proc(cards: ^[]Card) { delete(cards^) },
)
if just_created do state^ = make([]Card, COUNT)

ui.id("card", index)          // stable composite hash
ui.id("card", index, "title") // distinct cache/state
```

`get` accepts a default (`Maybe(T)`) and an optional destroy callback. State is
heap-allocated and evicted when not touched for a frame. The frame arena
(`ui.get_temp_allocator()`) is for strings and per-frame scratch only; the arena
is freed at the end of `ui.frame()`.

## Popups

`ui.popup(pos, size, fn)` and `ui.popup_with_poly(pos, size, payload, fn)`
enqueue a deferred **pre** callback. It runs after the main tree and before
input resolution, so it is topmost for hit-testing. The popup's `fn` draws in
the root coordinate space. Payloads must outlive the frame (the arena does) and
must not contain dangling `any` temporaries.

## Debugging

* Set a `debug` bool and call `ui.popup({}, root_size, ui.profiler)`; `demo/`
  toggles it with `D`.
* `ui.ctx.diagnostics` exposes frame/input/deferred/evict timings.
* `ui.is_visible()` and `ui.get_scope().clip` explain why a widget is culled.
* `ui.get_visible_rect()` / `ui.get_anchor()` are useful for tooltips.
* Run `odin build` (not `odin check -vet`) first; the library's current style
  triggers shadow/unused warnings under `-vet`, but it compiles cleanly.

## Scaling

There is no built-in scaling. The canonical approach is in `demo/scale.odin`:
render the UI into an offscreen texture sized `window * render_scale`, transform
logical coordinates to physical pixels in the callbacks, then blit the texture
to the window. Text must be rasterized at the physical size. See
`references/scaling.md` for the math, mipmap/filter trade-offs, mouse mapping,
scissor conversion, and the `maze-puzzle` variant using raylib fonts.

## Known limitations and fixed bugs

Read `references/pitfalls.md` for the full list. Highlights:

* Scopes/containers do not advance the parent cursor.
* `fit`/`center` use the previous frame's content size and converge one frame
  late.
* `Clip` is the hit-test rectangle; overflow-visible interaction is impossible.
* The repository's text tokenizer does not handle `\n`.
* `.Letter` wrapping and single-line/exact-fit widths were fixed in `ui/text.odin`
  in this repository; older vendored copies may still have the bugs.
* Store entries are frame-scoped; do not hold their pointers across frames.
