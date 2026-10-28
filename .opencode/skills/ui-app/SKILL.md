---
name: Odin UI
description: Build apps, tools, and game overlays with the backend-agnostic odin/ui library (github.com/carabalonepaulo/ui), including the ui-demo starter. Use for project setup/imports, layout (scopes, flex, stack, wrap, grid, list), cached text, input interests, the hashed store, popups, multi-page app architecture, backend integration, and scaling (raylib + fontstash is the included example).
---

# Odin UI

This repository is the library. Applications live outside it and consume it
through an Odin collection. The package named `ui` lives in `ui/` and depends
only on Odin's `core`; it does not know about raylib, windows, fonts, or scaling.
A backend supplies those through `ui.Callbacks`.

The [`ui-demo`](https://github.com/carabalonepaulo/ui-demo) repository is the
reference application and starter template: raylib + fontstash, the page
architecture, the dashboard, typography, and scaling pages. It is one backend
implementation, not a requirement.

| Path | Purpose |
| --- | --- |
| `ui/` | The library package. Import as `ui:.` through a collection. |
| `ui/headless/` | Deterministic backend for tests. No window, no GPU. |
| `test/` | Scratch test app shipped with the library. |
| `tests/` | Library unit tests, run with `odin test`. |
| `.opencode/skills/ui-app` | This skill. |
| `ui-demo/src/main.odin` | Starter: backend callbacks and frame loop. |
| `ui-demo/src/app.odin` | Starter: shell, page registry, lifecycle, context. |
| `ui-demo/src/pages/` | Starter: page framework and page implementations. |
| `ui-demo/src/kit/` | Starter: colors, text helpers, buttons. |
| `ui-demo/src/scale.odin` | Starter: rlgl modelview scale + physical-pixel callbacks. |
| `ui-demo/src/renderer.odin` | Starter: fontstash atlas, font registry, text. |

Paths such as `ui/`, `test/`, and `src/` are relative to the app or clone root,
not to this skill directory.

Reference files:

* `references/api.md` - full API and signatures.
* `references/patterns.md` - layout, widgets, store, pages.
* `references/scaling.md` - backend-neutral scaling technique.
* `references/backends/raylib.md` - the included raylib + fontstash backend.
* `references/testing.md` - the headless backend and how to write tests.
* `references/pitfalls.md` - library-level traps and fixes.

## Set up a new app (outside this repo)

The recommended layout links the library as a git submodule at `ui/`. The
collection root is the **package folder** `ui/ui`, not the repository root, so
the import is `ui:.`:

```text
my-app/
├── ui/                  # git submodule -> carabalonepaulo/ui
│   ├── ui/              # the library package
│   ├── test/
│   └── .opencode/skills/ui-app/
├── src/
│   └── main.odin        # import ui "ui:."
├── assets/
├── ols.json
└── opencode.json
```

Inside a git repository:

```sh
git submodule add https://github.com/carabalonepaulo/ui.git ui
git submodule update --init --recursive
```

Or, for a quick experiment, a plain clone works the same:

```sh
git clone https://github.com/carabalonepaulo/ui.git ui
```

`ols.json` (editor/OLS support):

```json
{
  "collections": [
    { "name": "ui", "path": "ui/ui" }
  ]
}
```

Build/run with the same collection:

```sh
odin run src -collection:ui=ui/ui
odin build src -collection:ui=ui/ui -out:app.exe
```

A local checkout works the same way; point the collection at its package folder:

```json
{ "name": "ui", "path": "../odin/ui/ui" }
```

```sh
odin run src -collection:ui=../odin/ui/ui
```

A submodule pins the exact library commit. Update it deliberately with
`git submodule update --remote ui` (or check out a tag inside `ui/`) and commit
the gitlink.

Enable this skill in the app with `opencode.json`. The path is relative to the
app's working directory:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "skills": ["./ui/.opencode/skills"]
}
```

Alternatively, copy `ui/.opencode/skills/ui-app` into `.opencode/skills/` if you
want the skill committed with the app and independent of the library path.
For a global install, copy it to `~/.config/opencode/skills/ui-app`. If the
library is not at `./ui`, adjust the `skills` path accordingly (for example
`../odin/ui/.opencode/skills`).

### Starter template

The starter repository already has the submodule, collection, configs, pages,
and backend:

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

`just run`, `build`, `check`, and `screenshot` all initialize the submodule.
Without `just`:

```sh
git submodule update --init --recursive
odin run src -collection:ui=ui/ui
```

The starter's `src/` is the reference for every pattern in this skill.

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
ends run in reverse order at the end of that block. The starter, for example,
wraps them inside an rlgl matrix push/pop (`BeginTextureMode`/`EndTextureMode`
would work the same way if the pass rendered into a target).

The backend callbacks actually used today are: `get_mouse_pos`,
`get_mouse_wheel`, `is_mouse_pressed(.Left)`, `is_mouse_released(.Left)`,
`measure_text`, `draw_text`, `draw_rect`, `enable_scissors`,
`disable_scissors`. The other fields in `Callbacks` are reserved. See
`references/api.md`.

## Pages and app context

The code in `ui-demo/src/pages/` is a **reference architecture**, not part of the
library. It keeps the app core independent from individual screens:

```odin
// ui-demo/src/pages/pages.odin
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
starter's `--view` screenshot argument.

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
   `Text_Options` used to draw. The layout cache key includes text, font, size,
   spacing, line spacing, wrap mode, and the container width.
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
    tab_spaces     = 0,       // 0 means 4
}

size := ui.measure_text(ui.id("label"), {ui.AUTO, ui.AUTO}, "Save", &opts)
ui.scope_at({x, y}, size)
ui.text(ui.id("label"), size, "Save", opts)
```

`text` has a fast path when the measured text fits (or `wrap == .None`) and the
text has no `\n`, `\r`, or `\t`; one backend call draws it. Otherwise it
tokenizes on spaces (`.Word`), runes (`.Letter`), tabs, and hard breaks.

`\n` and `\r\n` are hard breaks: they advance one line and are never drawn. A
trailing break keeps the empty last line, and indentation after a break is
preserved. `AUTO` width and `wrap == .None` disable automatic wrapping, not
explicit breaks. `\t` advances `tab_spaces` spaces (4 by default).

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
* Set a debug bool and call `ui.popup({}, root_size, ui.profiler)`; the starter
  toggles it with `D`.
* `ui.is_visible()` and `ui.get_scope().clip` explain why a widget is culled.
* `ui.get_visible_rect()` / `ui.get_anchor()` help with tooltips.
* Run `odin build` before `odin check -vet`; the library currently triggers
  shadow/unused warnings under `-vet` but compiles cleanly.

## Testing

`ui/headless` is a backend that draws nothing: it records rect/text/scissor
calls, measures text with fixed monospace metrics, and takes input from fields
you set. Use it to assert layout and hit-testing without a window or a GPU.

```odin
b: hl.Backend
if !hl.init(&b) do testing.fail_now(t, "headless init failed")
defer hl.deinit(&b)

hl.begin(&b, {400, 400})
size := ui.measure_text(ui.id("m"), {100, 100}, "aaa bbb", &opts)
hl.end(&b)
```

`ui` uses package globals, so run the test runner with one thread
(`-define:ODIN_TEST_THREADS=1`). See `references/testing.md`.

## Scaling

Scaling is a backend concern. The recommended shape is one rlgl modelview scale
for the whole UI pass: `ppu = ui_scale * dpi_scale`, `logical_size = window /
ppu`, push the matrix before `ui.frame()`, pop it after the last deferred draw.
Every `rl.Draw*` inside becomes physical pixels, including calls a component
makes directly, and no offscreen target is allocated.

Three things are not geometry and need explicit handling: the mouse position
(divide by `ppu`), the scissor rect (`glScissor` is in framebuffer pixels), and
text (disable the matrix and rasterize at `size * ppu`, otherwise glyphs blur).
`references/scaling.md` derives the math and covers pixel snapping, high-DPI,
cost, and when an offscreen target is still the right tool (supersampling, a
fixed virtual resolution, a 2D/3D viewport).

The library itself only ever sees logical units. Do not add a camera or a scale
factor inside the library.

## Known limitations

See `references/pitfalls.md` for details.

* Scopes/containers do not advance the parent cursor.
* `fit`/`center` use the previous frame's content size and converge one frame
  late.
* `Clip` is the hit-test rectangle; overflow-visible interaction is impossible.
* `\n` and `\r\n` are hard breaks and `\t` expands to `tab_spaces` spaces (4 by
  default). Other whitespace, such as NBSP, does not break words.
* A word wider than the container is never split; it overflows the scope and the
  reported width is clamped to the container.
* Horizontal text scroll only has an effect when the text does not wrap.
* `.Letter` wrapping and single-line/exact-fit widths were fixed in
  `ui/text.odin` in this repository; older copies may still have the bugs.
* Store entries are frame-scoped; do not hold their pointers across frames.
