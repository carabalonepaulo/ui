# API reference

All sizes and positions are `f64` logical units unless a signature says
otherwise. Functions with `id := -1` default to the current scope.

## Core types (`ui/types.odin`)

```odin
Vec2     :: [2]f64
Rect     :: [4]i32          // x, y, w, h (integer clip space)
Color    :: [4]u8           // r, g, b, a
Padding  :: struct { top, right, bottom, left: f64 }

Texture  :: distinct u64
Font     :: distinct u64
Id       :: distinct u64    // hash of any number of values

AUTO     :: -1              // content-sized axis for text/fit

Interest :: enum {
    Scroll_X, Scroll_Y,
    Hovered,
    Pressed, Pressed_Out,
    Released, Released_Out,
}
Interests :: bit_set[Interest]

Scope_Flag :: enum {
    Clip,                      // scissor drawing + hit-testing
    Propagate_Content_Size,    // report content size to the parent
    Pass_Through,              // continue interest propagation to the parent
}
Scope_Flags :: bit_set[Scope_Flag]

Scope :: struct {
    screen_pos, size, content_size, offset, cursor, pos: Vec2,
    clip: Rect,
    flags: Scope_Flags,
    interests: Interests,
    parent: int,
}

Anchor :: enum { Top_Left, Top, Top_Right, Left, Center, Right,
                 Bottom_Left, Bottom, Bottom_Right }

Mouse_Button :: enum i32 { Left, Right, Middle, Side, Extra, Forward, Back }
Keyboard_Key :: enum i32 { ... }   // values map 1:1 to raylib's KeyboardKey
```

## Context and frame (`ui/context.odin`)

```odin
init(callbacks: Callbacks, scope_capacity: int, frame_memory_bytes: int) -> bool
deinit()

frame()                       // @(deferred_none = end_frame)
begin_frame()
end_frame()                   // asserts all scopes are closed

get_temp_allocator() -> mem.Allocator   // frame arena
temp($T: typeid) -> ^T                  // allocate T in the frame arena
deferred(kind: Deferred_Kind, ud: rawptr, fn: proc(ud: rawptr))
deferred_with_poly(kind: Deferred_Kind, arg: $T, fn: proc(arg: T))
```

`end_frame` order: deferred `.Pre` (popups), input resolution, deferred `.Post`,
store eviction, arena free.

## Scopes (`ui/scope.odin`)

```odin
scope(size: Vec2, flags: Scope_Flags = {})             // deferred_none end_scope
scope_at(pos, size: Vec2, flags: Scope_Flags = {})     // deferred_none end_scope
begin_scope(size: Vec2, flags: Scope_Flags = {})
end_scope()

get_scope_id() -> int
get_scope(id := -1) -> ^Scope
get_parent_scope(id := -1) -> ^Scope
get_size(id := -1) -> Vec2
get_content_size(id := -1) -> Vec2
get_screen_pos(id := -1) -> Vec2
get_available_size(id := -1) -> Vec2      // size - cursor, clamped at 0
get_visible_rect(id := -1) -> [4]f64      // local to parent
is_visible(id := -1) -> bool
get_anchor(anchor: Anchor, id := -1) -> (Vec2, bool)  // optional_ok

to_screen_pos_at(id: int, local: Vec2) -> Vec2
to_local_pos_at(id: int, screen: Vec2) -> Vec2
to_screen_pos(local: Vec2) -> Vec2
to_local_pos(screen: Vec2) -> Vec2

is_scroll_at_start(axis: Dir, id := -1) -> bool
is_scroll_at_end(axis: Dir, id := -1) -> bool

bind(interest: Interest, ptr: rawptr)
```

A scope is positioned at the parent's cursor. `begin_scope` does **not** advance
the parent cursor. `end_scope` clamps bound scroll offsets and reports
`content_size` to the parent (always maxed; only propagated as an effective size
when `.Propagate_Content_Size` is set).

`scope` and `scope_at` are deferred to the end of the enclosing block. Use braces
to create siblings. `scope_at` temporarily sets the parent cursor to `pos` and
restores it.

## Drawing (`ui/draw.odin`)

```odin
draw_rect(pos, size: Vec2, color: Color)
draw_text(font: Font, text: string, pos: Vec2, size, spacing: f64, color: Color)
fill_rect(color: Color)              // from {0,0} to available size
```

These call the backend immediately. They use `to_screen_pos`, so the backend
receives logical screen coordinates (scope position - scroll offset).

A component that calls the backend directly has to apply the same offset
itself; there is no other conversion to do (see `references/scaling.md` for the
scale):

```odin
origin := ui.get_screen_pos()          // logical, includes scroll offsets
rl.DrawCircleV({f32(origin.x + 40), f32(origin.y + 40)}, 20, color)
```

## Measuring (`ui/scope.odin`, `ui/text.odin`)

```odin
measure_fixed(size: f64, count: int, gap := 0, padding := {0,0}) -> f64
measure_dynamic(items: []$T, fn: proc(item: T) -> f64, gap := 0, padding := {0,0}) -> f64
measure_padding(padding: Padding, dir: Dir) -> f64
measure_text(uid: Id, container_size: Vec2, text: string, opts: ^Text_Options,
             padding: Padding = {}) -> Vec2

measure :: proc { measure_fixed, measure_dynamic, measure_text, measure_padding }
```

`container_size.x == AUTO` disables automatic wrapping (explicit `\n` breaks still
apply) and returns the unclamped width. `opts.wrap == .None` does the same. The
layout cache is keyed by `uid + text + font + size + spacing + line_spacing +
tab_spaces + wrap + container.x`.

`padding` is added to the returned size; the wrap width stays
`container_size.x`. The intended use is to measure the full box once, then create
a scope of exactly that size for the content (with or without padding).

## Text (`ui/text.odin`)

```odin
Text_Wrap :: enum { None, Word, Letter }
Text_Sroll :: enum { None, X, Y, Both }   // historical typo: "Sroll"

Text_Options :: struct {
    wrap: Text_Wrap,
    letter_spacing: f64,
    line_spacing: f64,
    font: Font,
    font_size: f64,
    font_color: Color,
    scroll: Text_Sroll,
    tab_spaces: int,        // 0 means 4
}

text(uid: Id, size: Vec2, text: string, opts: Text_Options, flags: Scope_Flags = {})
```

* `size.x == AUTO`: disables wrap and horizontal scroll.
* `size.y == AUTO`: disables vertical scroll.
* Both `AUTO`: behaves as a fit scope with height `font_size`.
* Fast path: if the measured text fits (or `wrap == .None`) and the text has no
  `\n`, `\r`, or `\t`, draws once with a single backend call.
* Wrapped path: tokenizes on spaces (`.Word`), runes (`.Letter`), tabs, and line
  breaks, wraps when the next token does not fit, and draws each token.
* `\n` and `\r\n` are hard line breaks: they advance one line and are never
  drawn. A trailing break keeps the empty last line, and indentation after a
  break is preserved. `AUTO` width and `wrap == .None` disable automatic
  wrapping, not explicit breaks.
* `\t` advances `opts.tab_spaces` spaces (zero means 4) and separates words in
  `.Word`.
* A text containing `\n`/`\r`/`\t` always uses the token layout; the fast path is
  skipped because one backend call cannot break lines or expand a tab.
* The wrapped layout preserves the source: a run of spaces keeps its width, and
  whitespace at a line break is not drawn and does not count toward the measured
  width. `measure_text` returns the ink width of the widest line, so centering
  and right-aligning with it is exact.
* A word wider than the container is never split. It overflows its scope and the
  reported width is clamped to the container; `.Clip` is what removes the visual
  overflow.
* Horizontal scroll only has an effect when the text does not wrap: with
  `.Word`/`.Letter` the content width is clamped to the container by design, and
  `size.x == AUTO` disables X scroll.
* `scroll` binds `get(id(uid, 'x'/'y'), f64)` on the text scope.

## Layout

### Flex (`ui/flex.odin`)

```odin
Layout_Kind :: enum { Absolute, Flex }
Layout_Item :: struct { kind: Layout_Kind, value: f64 }

Flex :: struct { inner_flags, dir, current_child, computed, gap }

flex(size: Vec2, dir: Dir, items: []Layout_Item, gap := 0,
     flags: Scope_Flags = {}, inner_flags: Scope_Flags = {}) -> Flex
begin_flex(...) -> Flex
flex_next(state: ^Flex) -> bool      // @(deferred_in_out = end_flex_child)
```

`remaining = size[dir] - gaps - sum(.Absolute)`. Each `.Flex` item gets
`value / total_flex * remaining` (negative if absolutes overflow; clamp in the
caller). Each child is `{computed, container cross-size}`.

### Stack (`ui/stack.odin`)

```odin
Stack :: struct { inner_flags, dir, fit, gap }
stack(uid: Id, dir: Dir, gap := 0, flags = {}, inner_flags = {}) -> Stack
begin_stack(...) -> Stack
stack_next(state: ^Stack, size: Vec2) -> bool   // @(deferred_in = end_stack_next)
end_stack(state: Stack)
```

Auto-fits both axes. Children flow on `dir` with `gap`. The first frame uses the
previous content size (zero on first use), so it converges one frame late.

### Wrap (`ui/wrap.odin`)

```odin
Wrap :: struct { container_scope, content_scope, cursor, line_height,
                 usable_size, gap, padding }
wrap(uid: Id, size: Vec2, gap: Vec2 = {}, padding: [4]f64 = {}) -> Wrap
begin_wrap(...) -> Wrap
wrap_next(state: ^Wrap, item_size: Vec2) -> bool  // deferred_in_out
end_wrap(state: Wrap)                            // deferred_out
```

Flows fixed-size items into lines. The outer scope is `size`; the inner clipped
scope is `size - padding`. The parent cursor advances by `size.y` (not by the
content height). Bind `.Scroll_Y` on the inner scope for scrolling.

### List / Grid (`ui/list.odin`, `ui/grid.odin`)

```odin
list(offset: ^f64, size: Vec2, count: int, item_height, gap: f64,
     ud: rawptr, item: proc(i: int, ud: rawptr))

list_with_poly(offset, size, count, item_height, gap, ud: $T,
               item: proc(i: int, ud: T))

grid(offset: ^f64, size: Vec2, count: int, item_base_size: Vec2, gap: Vec2,
     ud: rawptr, item: proc(i: int, ud: rawptr),
     flags: Scope_Flags = {}, item_flags: Scope_Flags = {})

grid_with_poly(offset, size, count, item_base_size, gap, ud: $T,
               item: proc(i: int, ud: T), flags = {}, item_flags = {})
```

Both bind `.Scroll_Y` to `offset`, clamp it at `end_scope`, skip off-screen
items, and set `content_size`. Grid derives columns and cell aspect from
`item_base_size`; list uses a fixed `item_height`. `list` always clips its
container and does not take flags; use `grid` (which does) if you need a custom
clip policy.

### Padding / Center / Fit

```odin
padding(padding: Padding, flags: Scope_Flags = {})   // deferred_none end_padding
begin_padding(padding, flags = {})
end_padding()

center(uid: Id, content_size := Vec2{AUTO, AUTO}) -> Center  // deferred_out
begin_center(uid, content_size) -> Center
end_center(center: Center)

fit(uid: Id, size: Vec2, flags = {}) -> Fit   // deferred_out
begin_fit(uid, size, flags = {}) -> Fit
end_fit(fit: Fit)
```

`padding` creates an outer scope of the available size, offsets the cursor by
`left/top`, and an inner scope of the remaining size.

`center` centers the previous frame's content size. With `{AUTO, AUTO}` it
starts a fit scope and stores the measured content size for the next frame.

`fit` gives a scope the previous content size (or the requested fixed axis),
then stores the current content size. Fixed axes never shrink below the content.

## Global store (`ui/store.odin`)

```odin
id(args: ..any) -> Id
get(id: Id, $T: typeid, default: Maybe(T) = nil,
    destroy: proc(ptr: ^T) = nil) -> (^T, bool)   // optional_ok
exists(id: Id) -> bool
```

`get(id, T)` returns the pointer; `get(id, T)` with two results also returns
`just_created`. Entries not touched during a frame are destroyed at the end of
that frame. Store pointers are only valid for the current frame.

## Popups (`ui/popup.odin`)

```odin
popup(pos, size: Vec2, fn: proc())
popup_with_poly(pos, size: Vec2, arg: $T, fn: proc(arg: T))
```

Deferred `.Pre`: runs after the main tree, before input resolution, with the
root scope as parent. The `pos` is in root coordinates. Use it for tooltips,
menus, and the profiler.

## Backend callbacks (`ui/types.odin`)

```odin
Callbacks :: struct {
    get_delta_time:    proc() -> f64,
    get_default_font:  proc() -> Font,
    load_texture:      proc(path: string) -> Texture,
    load_font:         proc(path: string) -> Font,
    get_mouse_pos:     proc() -> Vec2,
    get_mouse_wheel:   proc() -> Vec2,
    is_mouse_pressed:  proc(btn: Mouse_Button) -> bool,
    is_mouse_down:     proc(btn: Mouse_Button) -> bool,
    is_mouse_released: proc(btn: Mouse_Button) -> bool,
    is_mouse_up:       proc(btn: Mouse_Button) -> bool,
    is_key_pressed:    proc(key: Keyboard_Key) -> bool,
    is_key_down:       proc(key: Keyboard_Key) -> bool,
    is_key_released:   proc(key: Keyboard_Key) -> bool,
    is_key_up:         proc(key: Keyboard_Key) -> bool,
    measure_text:      proc(font: Font, text: string, font_size, spacing: f64) -> Vec2,
    draw_text:         proc(font: Font, text: string, x, y, size, spacing: f64, color: Color),
    draw_rect:         proc(x, y, w, h: f64, color: Color),
    draw_texture:      proc(texture: Texture, src: [4]f64, dst: [4]f64, color: Color),
    enable_scissors:   proc(x, y, w, h: i32),
    disable_scissors:  proc(),
}
```

Currently called by the library: `get_mouse_pos`, `get_mouse_wheel`,
`is_mouse_pressed(.Left)`, `is_mouse_released(.Left)`, `measure_text`,
`draw_text`, `draw_rect`, `enable_scissors`, `disable_scissors`. The rest are
reserved; fill them if the library starts using them, or leave them nil.

## Diagnostics (`ui/diagnostics.odin`)

```odin
Diagnostics :: struct { frame, input, deferred_pre, deferred_post, evict: time.Duration }
profiler()           // 300px wide panel of timings and counts
format_bytes(bytes: u64) -> string
```

Use `ui.popup({0, 0}, root_size, ui.profiler)`.

## Starter page framework (ui-demo, not part of the library)

`ui-demo/src/pages/` contains a small application architecture. It is reference
code, not a library API. The shell owns chrome and lifecycle; pages own their
state and drawing.

```odin
// ui-demo/src/pages/pages.odin
Page :: enum { Dashboard, Typography, Scaling }

Scale_Info :: struct {
    window_size:     [2]int,
    logical_size:    Vec2,
    ui_scale:        f64,
    pixels_per_unit: f64,
    snap:            bool,
    atlas_size:      [2]int,   // the only UI-owned texture left
}

Context :: struct {
    go_to:               proc(page: Page, ud: rawptr = nil),
    set_scroll_modifier: proc(modifier: f32),
    load_font:           proc(name: string, size: f64) -> Font,
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

Lifecycle:

* `on_ready(self, ctx)` runs once after construction. Store `ctx` and load
  fonts there.
* `on_enter(self, ud)` runs when the page becomes current. `ud` is the payload
  passed to `go_to`; it is valid for the frame in which the switch is applied.
* `on_update(self)` runs every frame inside the shell's content scope.
* `on_exit(self)` runs when leaving.
* `destroy(self)` frees page-owned memory at shutdown.

`ui-demo/src/app.odin` owns the `PAGE_CTORS` registration array, current/next
page, `find_page`, `change_page`, and the `Context` implementation. A page is
added without touching the shell:

```odin
PAGE_CTORS :: [?]proc() -> pages.Interface {
    dashboard.create,
    typography.create,
    scaling.create,
    // new_page.create,
}
```

The app applies queued `go_to` calls at the end of the frame, so payloads
allocated from the UI frame arena are still alive.

