---
name: Odin UI
description: Build apps, tools, and game overlays with the backend-agnostic immediate-mode UI library in this repository. Use for layout (scopes, flex, stack, wrap, grid, list), cached text, input interests, the hashed store, popups, multi-page app architecture, and backend integration/scaling (raylib + fontstash is the included example).
---

# Odin UI

This repository contains the library, not an application. The package named
`ui` lives in `ui/` and depends only on Odin's `core`. It does not know about
raylib, windows, fonts, or scaling; a backend supplies those through
`ui.Callbacks`.

`demo/` is a complete reference application using raylib + fontstash. It is one
backend implementation, not a requirement. Use it as a working example and a
page-architecture template. Paths such as `ui/` and `demo/` are relative to the
repository root, not to this skill directory.

| Path | Purpose |
| --- | --- |
| `ui/` | The library (`import ui "../ui"` or a collection). |
| `test/` | Original scratch test app. Useful for unusual APIs. |
| `demo/main.odin` | Backend callbacks and the frame loop. |
| `demo/app.odin` | App shell, page registry, lifecycle, injected `Context`. |
| `demo/pages/` | Page framework and page implementations. |
| `demo/kit/` | Demo-only colors, text helpers, buttons. |
| `demo/scale.odin` | Render-to-texture + supersampled scaling. |
| `demo/renderer.odin` | Fontstash atlas, font registry, text rendering. |

Reference files:

* `references/api.md` - full API and signatures.
* `references/patterns.md` - layout, widgets, store, pages.
* `references/scaling.md` - backend-neutral scaling technique.
* `references/backends/raylib.md` - the included raylib + fontstash backend.
* `references/pitfalls.md` - library-level traps and fixes.

## Core model

* **Immediate mode.** One function builds the whole frame. There is no retained
  widget tree and no style system.
* **Logical units.** All coordinates and sizes are `f64` logical units. The
  backend converts them to physical pixels. The library never assumes pixels.
* **Scopes.** A `Scope` is an axis-aligned rectangle with a cursor.
  `begin_scope` places it at the parent cursor but does **not** advance the
  parent cursor. `end_scope` reports its content size upward.
* **Interests.** `ui.bind(.Hovered, &bool)` registers a pointer on the current
  scope. The backend injects mouse state, and the library resolves the topmost
  scope under the pointer at the end of the frame.
* **Store.** Per-widget state lives in a hashed store keyed by `ui.Id`. Entries
  not touched during a frame are evicted.
* **One frame.** `ui.frame()` resets the scope buffer, runs deferred popups,
  resolves input, evicts state, and frees the frame arena.

## Minimum frame

The library is backend-agnostic; this is the shape every host follows:

```odin
assert(ui.init(callbacks, scope_capacity, frame_memory_bytes))
defer ui.deinit()

for app_running() {
    // Begin whatever frame the backend needs (window, render target, ...).

    {
        ui.frame()
        ui.scope(root_size)
        draw_app()
    }

    // End the backend frame.
}
```

Keep `ui.frame()` and the root `ui.scope()` in the same block: their deferred
ends run in reverse order at the end of that block. The demo, for example,
wraps them inside `BeginTextureMode`/`EndTextureMode`.

The backend callbacks actually used today are: `get_mouse_pos`,
`get_mouse_wheel`, `is_mouse_pressed(.Left)`, `is_mouse_released(.Left)`,
`measure_text`, `draw_text`, `draw_rect`, `enable_scissors`,
`disable_scissors`. The other fields in `Callbacks` are reserved. See
`references/api.md`.

## Pages and app context

The code in `demo/pages/` is a **reference architecture**, not part of the
library. It keeps the app core independent from individual screens:

```odin
// demo/pages/pages.odin
Context :: struct {
    go_to:               proc(page: Page, ud: rawptr = nil),
    set_scroll_modifier: proc(modifier: f32),
    load_font:           proc(name: string, size: f64) -> ui.Font,
    scale_info:          proc() -> Scale_Info,
}

Interface :: struct {
    self:      rawptr,
    page:      Page,
    label:     string,
    on_ready:  proc(self: rawptr, ctx: Context),
    on_enter:  proc(self: rawptr, ud: rawptr),
    on_update: proc(self: rawptr),
    on_exit:   proc(self: rawptr),
    destroy:   proc(self: rawptr),
}
```

The app:

1. Constructs every page from a `PAGE_CTORS` array and calls `on_ready(self,
   ctx)` once.
2. Owns `current_page` and `next_page`. Pages call `ctx.go_to(...)`; the app
   applies the change at the end of the frame (so arena payloads are still
   valid) and calls `on_exit`/`on_enter`.
3. Calls the current page's `on_update` inside the content region. The shell
   (header, sidebar, footer) never contains page-specific code.
4. Injects shared systems through `Context`: navigation, scroll speed, font
   loading, and any render/scale information pages need.

Fonts cross systems, so they belong in `Context`:

```odin
on_ready :: proc(self: ^State, ctx: pages.Context) {
    self.ctx = ctx
    self.font_bold = ctx.load_font("bold", 16)
    self.font_body = ctx.load_font("regular", 13)
}
```

`size` is a hint for backends with per-size atlases. An on-demand rasterizer can
ignore it (the same handle works at any `font_size`); a per-size cache can
include it in the key.

To add a page: create one `State`, one `create() -> pages.Interface`, add the
constructor to `PAGE_CTORS`, and add the enum value. The shell, sidebar, and
navigation pick it up automatically. Add it to `PAGE_ORDER` only if you use the
demo's `--view` screenshot argument.

## Golden rules

1. **Know the size.** There is no constraint solver. Use explicit sizes,
   `ui.get_available_size()`, or `ui.measure_*`.
2. **Scopes do not flow.** `scope`, `scope_at`, `flex`, `stack`, `wrap`, `list`,
   and `grid` do not advance the parent cursor. Use `ui.next` on a
   stack/flex/wrap, `scope_at` for regions, or `padding`/`center` for groups.
3. **Blocks control lifetimes.** Deferred functions end with the enclosing
   block. Use `{ ... }` for siblings inside one procedure.
4. **Ids are identity.** State, text caches, scroll offsets, and fit sizes are
   keyed by `ui.Id`. Include the item index in ids.
5. **Touch state every frame.** An entry not fetched with `ui.get` in a frame is
   evicted at the end of it. Store pointers are frame-scoped.
6. **Bind on the scope that owns the interaction.** `bind(.Hovered, &value)` is
   checked against the scope's clipped rectangle. `.Pass_Through` lets a parent
   receive the same interest.
7. **Clip is also hit-testing.** `Clip` limits drawing and hit-testing;
   overflow-visible hit areas are not supported.
8. **Measure text; do not guess.** Use `ui.measure_text` with exactly the same
   `Text_Options` used to draw. The cache key includes text, font, size,
   spacing, and line spacing.
9. **Backend text must match the physical size.** Rasterize at
   `font_size * pixels_per_unit` or keep an atlas at that size. See
   `references/scaling.md`.
10. **Deferred payloads must not point at stack temporaries.** Do not put `any`
    values in a popup payload; store concrete strings or allocate on the frame
    arena.
11. **Register pages, don't edit the core.** New screens go in `pages/` and
    `PAGE_CTORS`, not in the shell.

## Layout building blocks

```odin
// Absolute placement. Ends at the end of the block.
ui.scope_at({x, y}, {w, h})

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

`flex` distributes `size - gaps - absolute` between `.Flex` items by weight.
`stack` auto-fits (previous frame's size on first use). `wrap` advances the
parent in Y. `list`/`grid` own their scroll offset and content size.

## Text

```odin
opts := ui.Text_Options {
    font           = my_font,
    font_size      = 16,
    font_color     = {230, 230, 230, 255},
    wrap           = .Word,   // .None, .Word, .Letter
    scroll         = .Y,      // only inside a fixed-size clipped scope
    letter_spacing = 0,
    line_spacing   = 4,
}

size := ui.measure_text(ui.id("label"), {ui.AUTO, ui.AUTO}, "Save", &opts)
ui.scope_at({x, y}, size)
ui.text(ui.id("label"), size, "Save", opts)
```

`text` has a fast path when the measured text fits (or `wrap == .None`). The
wrapped path tokenizes on spaces (`.Word`) or runes (`.Letter`). The current
tokenizer does not treat `\n` as a line break; use separate text calls for
paragraphs.

`opts.scroll` binds the text's own scroll offset. Do not also bind
`.Scroll_Y` on the same scope.

## Input

```odin
hovered := ui.get(ui.id("button/hover"), bool)
pressed := ui.get(ui.id("button/pressed"), bool)

ui.scope_at(pos, size)
ui.bind(.Hovered, hovered)
ui.bind(.Pressed, pressed)

if pressed^ do ui.fill_rect(pressed_color)
```

Interests: `.Hovered`, `.Pressed`, `.Pressed_Out`, `.Released`,
`.Released_Out`, `.Scroll_X`, `.Scroll_Y`. The backend resolves the left mouse
button and the wheel; keyboard callbacks exist but the current library does not
call them. Query your backend directly for keys.

Input is resolved at `end_frame`, so flags read while drawing are one frame
behind. `.Pressed` is true for one draw frame. Use `.Released` for completion if
needed.

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

`get` accepts a default (`Maybe(T)`) and an optional destroy callback. Store
memory uses the normal allocator; the frame arena is for strings and scratch and
is freed at the end of `ui.frame()`.

## Popups

`ui.popup(pos, size, fn)` and `ui.popup_with_poly(pos, size, payload, fn)`
enqueue a deferred **pre** callback. It runs after the main tree, before input
resolution, in root coordinates, so it is topmost for hit-testing. Payloads must
outlive the frame and must not contain dangling `any` temporaries.

## Debugging

* `ui.ctx.diagnostics` exposes frame/input/deferred/evict timings.
* Set a debug bool and call `ui.popup({}, root_size, ui.profiler)`; the demo
  toggles it with `D`.
* `ui.is_visible()` and `ui.get_scope().clip` explain why a widget is culled.
* `ui.get_visible_rect()` / `ui.get_anchor()` help with tooltips.
* Run `odin build` before `odin check -vet`; the library currently triggers
  shadow/unused warnings under `-vet` but compiles cleanly.

## Scaling

Scaling is a backend concern. The recommended shape is: render the UI into an
offscreen target larger than the destination, transform logical coordinates to
physical pixels in the callbacks, rasterize text at the physical size, then
downsample the target to the window. `references/scaling.md` derives the math,
covers filtering and mipmaps, and discusses high-DPI and cost.

The library itself only ever sees logical units. Do not add a camera or a scale
factor inside the library.

## Known limitations

See `references/pitfalls.md` for details.

* Scopes/containers do not advance the parent cursor.
* `fit`/`center` use the previous frame's content size and converge one frame
  late.
* `Clip` is the hit-test rectangle; overflow-visible interaction is impossible.
* The tokenizer does not handle `\n`.
* `.Letter` wrapping and single-line/exact-fit widths were fixed in
  `ui/text.odin` in this repository; older copies may still have the bugs.
* Store entries are frame-scoped; do not hold their pointers across frames.
