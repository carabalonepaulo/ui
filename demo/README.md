# Odin UI demo

A small, complete application built with the `ui` package in this repository.
It is the reference backend for raylib, fontstash, and supersampled scaling,
and it doubles as the reference architecture for multi-page apps.

## Run

From `demo/`:

```sh
just run
```

From the repository root:

```sh
odin run demo
```

Build only:

```sh
odin build demo -out:demo.exe
```

## What it shows

* A page shell: the core owns the header, sidebar, content area, and footer;
  pages only draw their own content.
* Page lifecycle and navigation: `pages.Context`, `Interface`, `on_ready`,
  `on_enter`, `on_update`, `on_exit`, `destroy`.
* Font loading through the injected `Context` (`ctx.load_font("bold", 16)`).
* A virtualized, scrollable grid of cards with hover/press state.
* A typography page with word-wrapped, vertically scrollable text.
* A scaling page that reports the current render-target metrics.
* A debug profiler overlay (`D`) and live scale/supersampling controls.

## Controls

| Input | Action |
| --- | --- |
| Mouse wheel | Scroll the grid or the typography panel |
| `-` / `=` | UI scale down / up (0.5x to 1.5x) |
| `[` / `]` | Supersampling down / up (1x to 4x) |
| `R` | Reset scale to 1x and supersampling to 2x |
| `D` | Toggle the UI profiler |
| Sidebar `-` / `+` | Same scale controls with the mouse |

## Layout

```text
demo/
├── main.odin          # window, backend callbacks, frame loop
├── scale.odin         # offscreen target + physical-pixel callbacks
├── renderer.odin      # fontstash atlas, font registry, text quads
├── app.odin           # shell, page registry, lifecycle, Context implementation
├── kit/
│   └── kit.odin       # colors, text helpers, buttons, page header
├── pages/
│   ├── pages.odin     # Page enum, Interface, Context, payloads
│   ├── dashboard/
│   │   ├── main.odin  # state + lifecycle
│   │   └── view.odin  # drawing
│   ├── typography/
│   └── scaling/
└── assets/fonts/
```

## Pages

A page is a state object plus a `pages.Interface`:

```odin
State :: struct {
    ctx:       pages.Context,
    font_bold: ui.Font,
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
```

The app injects the same `Context` into every page:

* `go_to(page, payload)` queues a page change. It is applied at the end of the
  frame, so payloads allocated in the frame arena are still valid.
* `load_font(name, size)` returns a `ui.Font`. Fontstash is size-independent, so
  the demo's size argument is a hint; a backend that bakes atlases per size can
  use it.
* `set_scroll_modifier(modifier)` lets a page tune the wheel speed.
* `scale_info()` reports window/logical/target sizes and scale factors for
  pages that need to visualize the render target.

The shell iterates `app.page_list` for the sidebar and calls the current page's
`on_update` inside the content region. `PAGE_CTORS` in `app.odin` is the only
place a page is registered; the core shell does not know any page-specific
details.

## How the scaling works

The UI works in logical pixels. For a window of `dest_size`:

```text
pixels_per_unit = ui_scale * render_scale
texture_size    = ceil(dest_size * render_scale)
logical_size    = texture_size / pixels_per_unit
```

The UI renders into the texture, and the texture is blitted to the window. All
backend callbacks convert logical coordinates to texture pixels; text is
rasterized at `font_size * pixels_per_unit`. `render_scale > 1` is supersampling:
the texture is larger than the window and is downsampled at the end.

`render_scale = 2` uses bilinear downsampling, which is a 2x2 box filter at that
exact ratio. Higher factors generate mipmaps (or you can replace that with a
box-filter shader).

See `../.opencode/skills/ui-app/references/scaling.md` for the backend-neutral
technique and `.../references/backends/raylib.md` for the raylib/fontstash
implementation.

## Headless screenshots

For visual checks:

```sh
odin run . -- --screenshot out.png --view 2 --scale 1.5 --ssaa 3
```

`--view` is the page registration order: `0` (Dashboard), `1` (Typography), or
`2` (Scaling). The app exits after writing the screenshot. Raylib batches draw
calls, so the demo flushes the batch before reading the framebuffer.

## Notes

* Fonts live in `assets/fonts/` and are loaded by `renderer.odin`; the path
  helper accepts both `demo/assets/...` and `assets/...` working directories.
* The demo uses `../ui` as a relative import. If you copy it elsewhere, change
  the import or add a collection (`-collection:ui=path/to/ui`).
* The library's text tokenizer splits on spaces only; the demo's paragraphs are
  single strings without newlines.
