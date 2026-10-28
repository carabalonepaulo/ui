# Testing

The library ships a deterministic backend in `ui/ui/headless` (import
`ui:headless`). It creates no window and draws nothing: every draw call is
recorded, text is measured with fixed monospace metrics, and input comes from
fields you set. Layout and hit-testing can be asserted exactly, with no GPU, no
display, and no font files.

## Shape

```odin
import "core:testing"
import ui "ui:."
import hl "ui:headless"

@(test)
wraps_at_the_container :: proc(t: ^testing.T) {
    b: hl.Backend
    if !hl.init(&b) do testing.fail_now(t, "headless init failed")
    defer hl.deinit(&b)

    opts := ui.Text_Options{font_size = 10, wrap = .Word}

    hl.begin(&b, {400, 400})
    size := ui.measure_text(ui.id("m"), {100, 100}, "aaa bbb", &opts)
    hl.end(&b)

    testing.expect_value(t, size, ui.Vec2{70, 10})
}
```

`begin`/`end` call `begin_frame`/`begin_scope` and `end_scope`/`end_frame`
directly instead of relying on `defer`, so the recorded calls and the returned
sizes are available right after `end`. Scopes created inside the block with
`ui.scope`/`ui.scope_at` still close at the end of their own block.

## Metrics

| | |
| --- | --- |
| rune width | `options.advance` (10 by default) |
| spacing | `(runes - 1) * spacing` |
| measured height | always `font_size` |

The height is the contract the text layout assumes, so line positions are
predictable: line `n` starts at `n * (font_size + line_spacing)`.

## Recorded calls

`b.calls` holds `headless.Call` in draw order:

```odin
Call_Kind :: enum { Rect, Text, Scissor_Begin, Scissor_End }

Call :: struct {
    kind, pos, size, color, font, font_size, spacing, text,
}
```

`text` is cloned by the backend. `hl.reset(&b)` frees the copies and keeps the
configuration, which is handy between frames of the same test.

## Input

Set fields between frames:

```odin
b.mouse = {40, 20}
b.mouse_pressed = true
```

Pressed/released are level flags, not edges: set them for the frame that should
see them and clear them afterwards. Interests resolve in `end_frame`, so the
effects appear on the frame you set them for.

## One instance per process

`ui` keeps its context and store in package globals, so only one backend can be
active and tests cannot run in parallel. Run the test runner with a single
thread:

```sh
# in this repository
odin test tests -collection:ui=ui -define:ODIN_TEST_THREADS=1

# with the library as a submodule
odin test tests -collection:ui=ui/ui -define:ODIN_TEST_THREADS=1
```

`headless.init` returns `false` if the UI frame arena cannot be allocated.
