// Page framework for demo applications built on the UI library.
//
// This package is deliberately independent from the backend and from the app
// shell. A page owns one enum value, one state object, and a small lifecycle.
// Everything shared across systems (navigation, scroll speed, fonts, render
// scale) is injected through Context instead of imported from the app.
package pages

import ui "../../ui"

Page :: enum {
	Dashboard,
	Typography,
	Scaling,
}

Scale_Info :: struct {
	window_size:     [2]int,
	logical_size:    ui.Vec2,
	target_size:     [2]int,
	ui_scale:        f64,
	render_scale:    f64,
	pixels_per_unit: f64,
}

Context :: struct {
	go_to:               proc(page: Page, ud: rawptr = nil),
	set_scroll_modifier: proc(modifier: f32),
	// `size` is a hint for backends whose atlases are baked per size. A
	// fontstash backend can ignore it: the same handle works at any font size.
	load_font:           proc(name: string, size: f64) -> ui.Font,
	scale_info:          proc() -> Scale_Info,
}

Interface :: struct {
	self:      rawptr,
	// Identity and navigation.
	page:      Page,
	label:     string,
	// Lifecycle. on_ready receives the injected context; pages usually store it
	// and load their fonts there. on_update draws inside the content scope.
	on_ready:  proc(self: rawptr, ctx: Context),
	on_enter:  proc(self: rawptr, ud: rawptr),
	on_update: proc(self: rawptr),
	on_exit:   proc(self: rawptr),
	destroy:   proc(self: rawptr),
}

// Empty payloads exist so on_enter can be typed. Add fields when a page needs
// to receive data (a document id, a scroll target, a filter, ...).
Dashboard_Payload :: struct {}

Typography_Payload :: struct {}

Scaling_Payload :: struct {}
