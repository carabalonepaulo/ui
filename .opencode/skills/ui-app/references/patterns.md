# Patterns

These are the patterns used by `demo/`. They are deliberately small and
copy-pasteable.

## App shell

Because scopes do not flow, an app shell is easiest with absolute regions and
one block per region. The shell owns chrome; the current page owns the content:

```odin
app_draw :: proc(ud: rawptr) {
    size := app.scale.logical_size

    ui.scope(size)
    ui.fill_rect(C_BG)

    {
        ui.scope_at({0, 0}, {size.x, HEADER_H})
        draw_header()
    }
    {
        ui.scope_at({0, HEADER_H}, {SIDEBAR_W, size.y - HEADER_H - FOOTER_H})
        draw_sidebar()
    }
    {
        ui.scope_at({SIDEBAR_W, HEADER_H},
                    {size.x - SIDEBAR_W, size.y - HEADER_H - FOOTER_H})
        ui.fill_rect(C_BG)
        if page := app.find_page(app.current_page); page != nil {
            page.on_update(page.self)
        }
    }
    {
        ui.scope_at({0, size.y - FOOTER_H}, {size.x, FOOTER_H})
        draw_footer()
    }

    app.apply_pending_page()
}
```

The outer `ui.scope(size)` is closed at the end of `app_draw`. Each `{ ... }`
block creates a sibling region and closes its scope before the next one starts.

## Pages and injected context

The reference architecture lives in `demo/pages/` and `demo/app.odin`. It is not
part of the library; copy or adapt it for applications.

```odin
// pages/pages.odin
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

A page keeps its own state and receives everything shared through `Context`:

```odin
State :: struct {
    ctx:       pages.Context,
    font_bold: ui.Font,
    offset:    f64,
}

create :: proc() -> pages.Interface {
    return pages.Interface {
        self      = new(State),
        page      = .Dashboard,
        label     = "Dashboard",
        on_ready  = auto_cast on_ready,
        on_enter  = auto_cast on_enter,
        on_update = auto_cast on_update,
        on_exit   = auto_cast on_exit,
        destroy   = auto_cast destroy,
    }
}

on_ready :: proc(self: ^State, ctx: pages.Context) {
    self.ctx = ctx
    self.font_bold = ctx.load_font("bold", 16)
}

on_update :: proc(self: ^State) {
    // draw inside the content scope provided by the shell
}
```

The app:

* constructs each page from a `PAGE_CTORS` array and calls `on_ready(ctx)`,
* calls the current page's `on_update` inside the content region,
* queues `go_to` changes and applies them at the end of the frame, so payloads
  allocated on the frame arena are still valid,
* calls `on_exit` before `on_enter` and `destroy` at shutdown,
* implements `load_font` once (font registry) for all pages.

Adding a page is: a new `State`, a `create`, a `PAGE_CTORS` entry, and an enum
value. The shell and sidebar pick it up automatically.

Font loading crosses systems, so it belongs in `Context`:

```odin
self.font_body = ctx.load_font("regular", 13)
```

`size` is a hint for per-size atlases; an on-demand rasterizer can ignore it.

## Measure + align a single line

Text has no alignment API. Measure it, then put it in a scope of exactly that
size:

```odin
Text_Align :: enum { Left, Center, Right }

draw_text_line :: proc(uid: ui.Id, pos, area: ui.Vec2, text: string,
                       opts: ui.Text_Options, align := Text_Align.Left) {
    options := opts
    measured := ui.measure_text(uid, {ui.AUTO, ui.AUTO}, text, &options)

    x := pos.x
    switch align {
    case .Left:
    case .Center: x += (area.x - measured.x) * 0.5
    case .Right:  x += area.x - measured.x
    }
    y := pos.y + (area.y - options.font_size) * 0.5

    ui.scope_at({x, y}, measured)
    ui.text(uid, measured, text, options)
}
```

The same `uid` makes the measure cache and the text cache agree. Pass the
measured size to `text` to stay on its fast path and avoid a one-frame fit.

## Row with absolute + flexible cells

```odin
row := ui.flex(
    ui.get_available_size(), .X,
    {{.Absolute, 260}, {.Flex, 1}, {.Absolute, 340}},
    gap = 18,
)

if ui.next(&row) {
    draw_text_line(ui.id("title"), {}, ui.get_size(), "ODIN UI",
                   make_text_opts(FONT_BOLD, 22, C_TEXT))
}
if ui.next(&row) {
    draw_text_line(ui.id("subtitle"), {}, ui.get_size(), "a subtitle",
                   make_text_opts(FONT_REGULAR, 12, C_TEXT_DIM))
}
if ui.next(&row) {
    draw_badge(ui.get_size())
}
```

`ui.next` returns true while there are computed cells. Each `if` body is a
block, so its child scope closes before the next cell.

## Interactive button

State lives in the store and is fetched by id every frame. `pressed` is one
frame behind and true for one frame:

```odin
draw_button :: proc(uid: ui.Id, pos, size: ui.Vec2, label: string) -> bool {
    hovered := ui.get(ui.id(uid, "hover"), bool)
    pressed := ui.get(ui.id(uid, "pressed"), bool)

    ui.scope_at(pos, size)
    ui.bind(.Hovered, hovered)
    ui.bind(.Pressed, pressed)

    bg := C_PANEL
    if pressed^      do bg = C_PANEL_PRESSED
    else if hovered^ do bg = C_PANEL_HOVER
    ui.fill_rect(bg)

    draw_text_line(ui.id(uid, "label"), {}, size, label,
                   make_text_opts(FONT_REGULAR, 13, C_TEXT), .Center)

    return pressed^
}
```

The returned bool is read during the frame after the click. Apply state changes
at the end of the frame (or at the start of the next frame) so the widget's
visual and its model do not disagree.

## Nav with active state

```odin
view := app.view
hover := ui.get(ui.id("nav/hover"), [3]bool)
press := ui.get(ui.id("nav/press"), [3]bool)

for label, i in NAV_ITEMS {
    {
        ui.scope_at({0, 28 + f64(i) * 44}, {area.x, 36})

        if view == i {
            ui.fill_rect(C_NAV_ACTIVE)
            ui.draw_rect({0, 0}, {3, 36}, C_ACCENT)
        } else if hover[i] {
            ui.fill_rect(C_NAV_HOVER)
        }

        ui.bind(.Hovered, &hover[i])
        ui.bind(.Pressed, &press[i])

        draw_text_line(ui.id("nav", i), {16, 0}, {area.x - 16, 36}, label,
                       make_text_opts(FONT_REGULAR, 14, C_TEXT))
    }
}

for i in 0 ..< len(NAV_ITEMS) {
    if press[i] {
        view = i
        break
    }
}
```

`ui.bind` stores a pointer; the pointer must remain valid for the whole frame
(store memory or the application struct, not a local temporary that the
compiler may move).

## Virtualized grid

```odin
ui.grid_with_poly(
    &app.grid_offset,
    ui.get_available_size(),
    60,
    {250, 158},
    {16, 16},
    app.cards,
    proc(i: int, cards: []Card_State) {
        draw_card(i, &cards[i])
    },
    {.Clip},          // container clipping
    {.Clip},          // per-cell clipping
)
```

`grid` computes column count and cell size from the container width and the
item aspect ratio. It only builds visible rows. Keep the offset in application
state (or a store entry) so it survives while another view is shown.

## Scrollable text panel

```odin
opts := ui.Text_Options {
    font         = FONT_REGULAR,
    font_size    = 15,
    font_color   = C_TEXT_MUTED,
    wrap         = .Word,
    line_spacing = 6,
    scroll       = .Y,
}

ui.scope_at({0, 52}, {area.x, area.y - 52})
ui.text(ui.id("body"), ui.get_size(), LONG_PARAGRAPH, opts, {.Clip})
```

`text` binds its own scroll offset under `id(uid, 'y')`. Wheel over the scope
moves it. Do not also bind `.Scroll_Y` yourself; that would overwrite the text's
binding. The wheel callback must return a delta in logical units; the library
subtracts it from the bound offset and clamps it at `end_scope`.

## List

```odin
ui.list_with_poly(
    &offset,
    ui.get_available_size(),
    count, 22, 10,
    items,
    proc(i: int, items: ^[]Item) {
        ui.bind(.Hovered, &items[i].hover)
        if items[i].hover do ui.fill_rect(C_PANEL_HOVER)
        width := ui.get_size().x
        draw_text_line(ui.id("row", i), {12, 0}, {width - 24, 22},
                       items[i].text, make_text_opts(FONT_REGULAR, 13, C_TEXT))
    },
)
```

The item callback runs inside the per-item scope. `ui.get_size()` is the row
size. The list owns clipping and scroll.

## Popup/tooltip

```odin
if hovered {
    if anchor, ok := ui.get_anchor(.Bottom_Left); ok {
        ui.popup_with_poly(anchor, {220, 80}, state, proc(state: ^State) {
            ui.fill_rect({20, 22, 28, 245})
            ui.draw_rect({0, 0}, {220, 1}, C_BORDER)
            ui.padding({12, 12, 12, 12})
            draw_text_line(ui.id("tip/title"), {}, ui.get_available_size(),
                           "Tooltip", make_text_opts(FONT_BOLD, 14, C_TEXT))
        })
    }
}
```

The popup runs after the main tree, so it is topmost for input. `get_anchor`
returns the current scope's anchored screen position (root/logical
coordinates). The payload must not contain `any` values that reference stack
temporaries; store strings or arena-allocated structs.

## Store with owned slices

```odin
Cards_State :: struct {
    hover:    []bool,
    selected: []bool,
}

destroy_cards :: proc(state: ^Cards_State) {
    delete(state.hover)
    delete(state.selected)
}

state, created := ui.get(ui.id("cards"), Cards_State, destroy = destroy_cards)
if created {
    state.hover = make([]bool, COUNT)
    state.selected = make([]bool, COUNT)
}
```

The destroy callback runs when the entry is evicted or when `ui.deinit` is
called. Store memory uses the normal Odin allocator, not the frame arena.

## Center and fit

```odin
ui.center(ui.id("empty/center"), {240, 120})
ui.scope({240, 120})
ui.fill_rect(C_PANEL)
```

`center` uses the previous frame's content size for `{AUTO, AUTO}`. The first
frame is un-centered; every later frame is stable. For a fixed content size,
pass it explicitly and there is no lag.

```odin
{
    ui.fit(ui.id("auto/size"), {ui.AUTO, ui.AUTO})
    // build content; its size is stored for the next frame
}
// the fit scope closes at the end of the block above
```

Auto-sized containers are one frame behind by design. Do not animate their
contents and expect zero-latency layout.

## Debug overlay

```odin
debug := ui.get(ui.id("app/debug"), bool)
// Replace with your backend's key query; the raylib demo uses rl.IsKeyPressed.
if key_pressed(.D) do debug^ = !(debug^)
if debug^ do ui.popup({0, 0}, root_size, ui.profiler)
```

`ui.profiler` draws a 300px panel with frame/input/deferred/evict timings and
scope/store counts. It uses `draw_text` directly, so it is a good smoke test for
a new backend.

## Immediate-mode constraints

* The layout you build during a frame is the layout that is drawn. State changes
  applied during drawing usually take effect on the next frame.
* A widget cannot know its final size before its children are built. Use
  `measure_*` and explicit sizes, or accept the one-frame `fit`/`center` lag.
* No style cascade, no constraints solver, no automatic line height. Every
  visual decision is explicit.
* Parent clipping is part of the coordinate system: a child's clip rect is the
  intersection of its rect with the parent clip at begin time.
* A scope's `content_size` is always maxed from children; only
  `.Propagate_Content_Size` makes the parent use it as the scope's effective
  size.
