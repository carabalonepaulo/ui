// Package headless is a deterministic backend for ui.
//
// It draws nothing. Every rect, text, and scissor call is recorded, text is
// measured with fixed monospace metrics, and input comes from values the caller
// sets, so layout and hit-testing can be asserted without a window, a GPU, or
// font files.
//
//	b: headless.Backend
//	if !headless.init(&b) do return
//	defer headless.deinit(&b)
//
//	headless.begin(&b, {400, 400})
//	size := ui.measure_text(ui.id("label"), {100, 100}, "hello world", &opts)
//	ui.text(ui.id("label"), size, "hello world", opts)
//	headless.end(&b)
//
// `begin`/`end` use the non-deferred frame and scope entry points, so a test can
// read the recorded calls and the returned sizes right after `end`.
//
// Metrics: one rune is `options.advance` wide, plus `spacing` between adjacent
// runes. The measured height is always `font_size`, which is the contract the
// library's line layout expects.
package headless

import "core:mem"
import "core:strings"
import "core:unicode/utf8"
import ui "ui:."

// What a recorded call was.
Call_Kind :: enum {
	Rect,
	Text,
	Scissor_Begin,
	Scissor_End,
}

// One backend call. `text` is owned by the backend (cloned on record).
Call :: struct {
	kind:      Call_Kind,
	pos:       ui.Vec2,
	size:      ui.Vec2,
	color:     ui.Color,
	font:      ui.Font,
	font_size: f64,
	spacing:   f64,
	text:      string,
}

Options :: struct {
	// Width of one rune.
	advance:        f64,
	scope_capacity: int,
	frame_memory:   int,
	// Initial mouse position. `{ -1e9, -1e9 }` keeps it out of every scope.
	mouse:          ui.Vec2,
}

DEFAULT_OPTIONS :: Options {
	advance        = 10,
	scope_capacity = 4_096,
	frame_memory   = 4 * mem.Megabyte,
	mouse          = {-1e9, -1e9},
}

Backend :: struct {
	options:      Options,
	calls:        [dynamic]Call,
	in_frame:     bool,
	initialized:  bool,

	// Input state. Set these before `begin` to simulate a frame.
	mouse:          ui.Vec2,
	wheel:          ui.Vec2,
	mouse_pressed:  bool,
	mouse_released: bool,
}

@(private = "file")
active: ^Backend

// init registers the backend and initializes the UI context.
init :: proc(b: ^Backend, options := DEFAULT_OPTIONS) -> bool {
	b.options = options
	b.mouse = options.mouse
	active = b

	if !ui.init(callbacks(), options.scope_capacity, options.frame_memory) {
		active = nil
		return false
	}

	b.initialized = true
	return true
}

// deinit releases the UI context and the recorded calls.
deinit :: proc(b: ^Backend) {
	if b.initialized {
		ui.deinit()
		b.initialized = false
	}

	if active == b {
		active = nil
	}

	reset(b)
	delete(b.calls)
	b.calls = nil
}

// reset forgets the recorded calls, keeping the backend configured.
reset :: proc(b: ^Backend) {
	for call in b.calls {
		if call.text != "" do delete(call.text)
	}
	clear(&b.calls)
}

// begin starts a frame with a root scope of `size`.
begin :: proc(b: ^Backend, size: ui.Vec2) {
	assert(active == b, "headless.begin: backend is not active")
	assert(!b.in_frame, "headless.begin: a frame is already open")

	b.in_frame = true
	ui.begin_frame()
	ui.begin_scope(size)
}

// end closes the root scope and the frame.
end :: proc(b: ^Backend) {
	assert(active == b, "headless.end: backend is not active")
	assert(b.in_frame, "headless.end: no frame is open")

	ui.end_scope()
	ui.end_frame()
	b.in_frame = false
}

callbacks :: proc() -> ui.Callbacks {
	return ui.Callbacks {
		get_mouse_pos = proc() -> ui.Vec2 {
			return active.mouse
		},
		get_mouse_wheel = proc() -> ui.Vec2 {
			return active.wheel
		},
		is_mouse_pressed = proc(_: ui.Mouse_Button) -> bool {
			return active.mouse_pressed
		},
		is_mouse_down = proc(_: ui.Mouse_Button) -> bool {
			return active.mouse_pressed
		},
		is_mouse_released = proc(_: ui.Mouse_Button) -> bool {
			return active.mouse_released
		},
		is_mouse_up = proc(_: ui.Mouse_Button) -> bool {
			return !active.mouse_pressed
		},
		measure_text = proc(_: ui.Font, text: string, font_size, spacing: f64) -> ui.Vec2 {
			count := utf8.rune_count(text)
			width := f64(count) * active.options.advance
			if count > 1 do width += f64(count - 1) * spacing
			return {width, font_size}
		},
		draw_text = proc(
			font: ui.Font,
			text: string,
			x, y, size, spacing: f64,
			color: ui.Color,
		) {
			append(
				&active.calls,
				Call {
					kind = .Text,
					pos = {x, y},
					color = color,
					font = font,
					font_size = size,
					spacing = spacing,
					text = strings.clone(text, context.allocator),
				},
			)
		},
		draw_rect = proc(x, y, w, h: f64, color: ui.Color) {
			append(
				&active.calls,
				Call{kind = .Rect, pos = {x, y}, size = {w, h}, color = color},
			)
		},
		enable_scissors = proc(x, y, w, h: i32) {
			append(
				&active.calls,
				Call {
					kind = .Scissor_Begin,
					pos = {f64(x), f64(y)},
					size = {f64(w), f64(h)},
				},
			)
		},
		disable_scissors = proc() {
			append(&active.calls, Call{kind = .Scissor_End})
		},
	}
}
