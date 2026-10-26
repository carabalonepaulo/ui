# odin/ui

A small, backend-agnostic immediate-mode UI library for Odin.

* Explicit layout: scopes, flex, stack, wrap, list, grid.
* Cached text with word/letter wrapping and scrolling.
* Per-widget state in a hashed store, with automatic eviction.
* Input interests (hover, press, release, scroll) and deferred popups.
* No dependencies outside Odin's `core`; the backend supplies drawing, input,
  fonts, and scaling through `ui.Callbacks`.
* A companion starter app with raylib + fontstash:
  [`carabalonepaulo/ui-demo`](https://github.com/carabalonepaulo/ui-demo).

## Layout

```text
ui/          the library package
test/        scratch test application
.opencode/   the ui-app agent skill
LICENSE
```

## Use it in an application

The application lives in its own repository. Link this repository as a git
submodule and resolve the package through an Odin collection:

```text
my-app/
├── ui/                  # this repository (git submodule)
│   ├── ui/              # library package
│   └── test/
├── src/
│   └── main.odin        # import ui "ui:."
├── assets/
└── ols.json
```

```sh
git submodule add https://github.com/carabalonepaulo/ui.git ui
git submodule update --init --recursive
```

For a quick experiment, a plain clone works the same:

```sh
git clone https://github.com/carabalonepaulo/ui.git ui
```

The collection root is the package folder, not the repository root. `ols.json`:

```json
{
  "collections": [
    { "name": "ui", "path": "ui/ui" }
  ]
}
```

Build/run:

```sh
odin run src -collection:ui=ui/ui
odin build src -collection:ui=ui/ui -out:app.exe
```

### Local checkout

Point the collection at the package folder of any local clone:

```json
{ "name": "ui", "path": "../odin/ui/ui" }
```

```sh
odin run src -collection:ui=../odin/ui/ui
```

### Starter template

The fastest way to get a working app (raylib + fontstash, page architecture,
scaling, profiler):

```sh
git clone --recurse-submodules https://github.com/carabalonepaulo/ui-demo.git my-app
cd my-app
just run
```

The starter links this repository as a git submodule at `ui/`; `just run`/`build`
also initialize it with `git submodule update --init --recursive`.

## Minimal integration

The library does not create a window or a graphics context. Implement
`ui.Callbacks` for your backend, then drive one frame at a time:

```odin
assert(ui.init(callbacks, 65_536, 8 * mem.Megabyte))
defer ui.deinit()

for app_running() {
    // begin backend frame

    {
        ui.frame()
        ui.scope(root_size)
        draw_app()
    }

    // end backend frame
}
```

See the `src/` directory in the starter repository for a complete
raylib/fontstash backend and the UI patterns.

## Agent skill

The `ui-app` skill lives in `.opencode/skills/ui-app`. It documents the API,
layout patterns, the page architecture, backend integration, scaling, and known
pitfalls. To use it from an application, point OpenCode at the cloned skill:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "skills": ["./ui/.opencode/skills"]
}
```

Or copy `ui/.opencode/skills/ui-app` into `.opencode/skills/`. For a global
install, copy it to `~/.config/opencode/skills/ui-app`.

## License

MIT. See `LICENSE`.
