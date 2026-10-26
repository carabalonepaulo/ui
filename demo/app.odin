package demo

import "core:fmt"
import ui "../ui"
import rl "vendor:raylib"

// Layout constants are expressed in logical pixels.
HEADER_H :: 56
FOOTER_H :: 28
SIDEBAR_W :: 224

CARD_COUNT :: 60
NAV_COUNT :: 3

NAV_ITEMS := [?]string{"Dashboard", "Typography", "Scaling"}

PAGE_TITLES := [?]string{"Dashboard", "Typography", "Scaling"}
PAGE_SUBS := [?]string{
	"Immediate-mode cards in a virtualized grid. Hover and press are bound per card.",
	"Fontstash text rasterized at the physical pixel size, wrapped and scrolled by the UI library.",
	"Render above the destination resolution, then downsample for crisp UI at any scale.",
}

CARD_TITLES := [?]string{
	"Layout",
	"Scopes",
	"Flex",
	"Wrap",
	"Grid",
	"List",
	"Store",
	"Text",
	"Popups",
	"Clipping",
	"Interests",
	"Zero alloc",
}

CARD_DESCRIPTIONS := [?]string{
	"Scopes are rectangles. Nothing moves unless you move it, so every measurement is explicit and predictable.",
	"begin_scope starts a rectangle at the parent cursor. end_scope propagates its size back to the parent.",
	"Flexible rows and columns distribute the remaining size between .Flex items after .Absolute ones.",
	"Wrap flows fixed-size items into lines and reports its content size back to the parent.",
	"Grid virtualizes rows: only the visible cells are built, so huge collections stay cheap.",
	"List is the same idea for a single column, with a stable per-item height.",
	"State lives in a hashed store. Entries not touched during the frame are evicted automatically.",
	"Text is measured once and cached by a hash of the string, font, size and spacing.",
	"Deferred popups run after the main tree, so they can cover everything drawn before them.",
	"Clip enables scissor rectangles for rendering and also limits hit testing to the visible area.",
	"Bind an Interest to a bool or f64 field to receive hover, press, release or scroll.",
	"Draw calls are batched by raylib and the UI never allocates per frame outside its arena.",
}

CARD_TAGS := [?]string{"layout", "core", "layout", "layout", "scroll", "scroll", "state", "text", "overlay", "render", "input", "perf"}

CARD_ACCENTS := [?]ui.Color{
	{94, 234, 212, 255},
	{129, 140, 248, 255},
	{244, 114, 182, 255},
	{251, 191, 36, 255},
}

C_WINDOW_BG :: ui.Color{8, 9, 12, 255}
C_BG :: ui.Color{15, 17, 21, 255}
C_HEADER :: ui.Color{19, 22, 28, 255}
C_SIDEBAR :: ui.Color{17, 20, 25, 255}
C_FOOTER :: ui.Color{12, 14, 18, 255}
C_PANEL :: ui.Color{22, 26, 33, 255}
C_PANEL_HOVER :: ui.Color{28, 33, 42, 255}
C_PANEL_PRESSED :: ui.Color{35, 42, 54, 255}
C_BORDER :: ui.Color{38, 44, 56, 255}
C_ACCENT :: ui.Color{94, 234, 212, 255}
C_ACCENT_DIM :: ui.Color{38, 92, 86, 255}
C_TEXT :: ui.Color{232, 236, 244, 255}
C_TEXT_MUTED :: ui.Color{139, 148, 165, 255}
C_TEXT_DIM :: ui.Color{92, 101, 117, 255}
C_BADGE_BG :: ui.Color{25, 30, 38, 255}
C_NAV_ACTIVE :: ui.Color{27, 33, 41, 255}
C_NAV_HOVER :: ui.Color{22, 27, 34, 255}

Card_State :: struct {
	hovered: bool,
	pressed: bool,
}

Text_Align :: enum {
	Left,
	Center,
	Right,
}

Button_Style :: struct {
	bg:      ui.Color,
	hover:   ui.Color,
	pressed: ui.Color,
	border:  ui.Color,
	text:    ui.Color,
}

SMALL_BUTTON :: Button_Style {
	bg      = C_PANEL,
	hover   = C_PANEL_HOVER,
	pressed = C_PANEL_PRESSED,
	border  = C_BORDER,
	text    = C_TEXT,
}

TYPO_BODY :: "The UI library has no layout engine that guesses. You declare a scope, tell it how big it is, and then place things inside it. That sounds tedious, and it is, but it also means every frame costs the same and every position is known before it is drawn. Text is measured through the backend, wrapped by the library, and cached by a hash of its contents and options. Scroll offsets are bound to f64 values in the hashed store, so the same code can drive a list of ten items or a list of a million. The demo below is a single text scope: it wraps on word boundaries, clips to its rectangle, and scrolls vertically with the wheel."

make_text_opts :: proc(
	font: ui.Font,
	size: f64,
	color: ui.Color,
	wrap: ui.Text_Wrap = .None,
	line_spacing: f64 = 0,
) -> ui.Text_Options {
	return {
		font           = font,
		font_size      = size,
		font_color     = color,
		wrap           = wrap,
		line_spacing   = line_spacing,
		letter_spacing = 0,
	}
}

// Measures in logical space, centers vertically, then draws inside a scope of
// exactly the measured size. `pos` is relative to the current scope; `area` is
// the box used for horizontal alignment.
draw_text_line :: proc(
	uid: ui.Id,
	pos, area: ui.Vec2,
	text: string,
	opts: ui.Text_Options,
	align: Text_Align = .Left,
) {
	options := opts
	measured := ui.measure_text(uid, {ui.AUTO, ui.AUTO}, text, &options)
	x := pos.x
	switch align {
	case .Left:
	case .Center:
		x += (area.x - measured.x) * 0.5
	case .Right:
		x += area.x - measured.x
	}
	y := pos.y + (area.y - opts.font_size) * 0.5

	ui.scope_at({x, y}, measured)
	ui.text(uid, measured, text, opts)
}

draw_button :: proc(
	uid: ui.Id,
	pos, size: ui.Vec2,
	label: string,
	style: Button_Style,
	text_size: f64 = 13,
) -> bool {
	hovered := ui.get(ui.id(uid, "hover"), bool)
	pressed := ui.get(ui.id(uid, "pressed"), bool)

	ui.scope_at(pos, size)
	ui.bind(.Hovered, hovered)
	ui.bind(.Pressed, pressed)

	bg := style.bg
	if pressed^ {
		bg = style.pressed
	} else if hovered^ {
		bg = style.hover
	}

	ui.fill_rect(bg)
	ui.draw_rect({0, 0}, {size.x, 1}, style.border)
	ui.draw_rect({0, size.y - 1}, {size.x, 1}, style.border)
	ui.draw_rect({0, 0}, {1, size.y}, style.border)
	ui.draw_rect({size.x - 1, 0}, {1, size.y}, style.border)

	opts := make_text_opts(FONT_REGULAR, text_size, style.text)
	draw_text_line(ui.id(uid, "label"), {}, size, label, opts, .Center)

	return pressed^
}

app_draw :: proc(ud: rawptr) {
	size := app.scale.logical_size
	next_view := app.view

	ui.scope(size)
	ui.fill_rect(C_BG)

	{
		ui.scope_at({0, 0}, {size.x, HEADER_H})
		draw_header()
	}
	{
		ui.scope_at({0, HEADER_H}, {SIDEBAR_W, size.y - HEADER_H - FOOTER_H})
		next_view = draw_sidebar(app.view)
	}
	{
		ui.scope_at({SIDEBAR_W, HEADER_H}, {size.x - SIDEBAR_W, size.y - HEADER_H - FOOTER_H})
		draw_content(app.view)
	}
	{
		ui.scope_at({0, size.y - FOOTER_H}, {size.x, FOOTER_H})
		draw_footer()
	}

	app.view = next_view

	debug := ui.get(ui.id("app/debug"), bool)
	if rl.IsKeyPressed(.D) {
		debug^ = !(debug^)
	}
	if debug^ {
		ui.popup({0, 0}, size, ui.profiler)
	}
}

draw_header :: proc() {
	ui.fill_rect(C_HEADER)
	ui.draw_rect({0, HEADER_H - 1}, {ui.get_size().x, 1}, C_BORDER)

	{
		ui.padding({0, 22, 0, 22})
		row := ui.flex(
			ui.get_available_size(),
			.X,
			{{.Absolute, 260}, {.Flex, 1}, {.Absolute, 340}},
			gap = 18,
		)

		if ui.next(&row) {
			draw_text_line(
				ui.id("header/title"),
				{},
				ui.get_size(),
				"ODIN UI",
				make_text_opts(FONT_BOLD, 22, C_TEXT),
				.Left,
			)
		}
		if ui.next(&row) {
			draw_text_line(
				ui.id("header/subtitle"),
				{},
				ui.get_size(),
				"immediate-mode layout · explicit sizes · raylib + fontstash",
				make_text_opts(FONT_REGULAR, 12, C_TEXT_DIM),
				.Left,
			)
		}
		if ui.next(&row) {
			draw_scale_badge(ui.get_size())
		}
	}
}

draw_scale_badge :: proc(area: ui.Vec2) {
	label := fmt.aprintf(
		"scale %.2fx   ·   ssaa %.2fx   ·   %d x %d",
		app.scale.ui_scale,
		app.scale.render_scale,
		app.scale.target.texture.width,
		app.scale.target.texture.height,
		allocator = ui.get_temp_allocator(),
	)
	opts := make_text_opts(FONT_BOLD, 11, C_ACCENT)

	measured := ui.measure_text(ui.id("header/badge/label"), {ui.AUTO, ui.AUTO}, label, &opts)
	width := measured.x + 24
	height := measured.y + 12
	x := area.x - width
	y := (area.y - height) * 0.5

	{
		ui.scope_at({x, y}, {width, height})
		ui.fill_rect(C_BADGE_BG)
		ui.draw_rect({0, 0}, {width, 1}, C_BORDER)
		ui.draw_rect({0, height - 1}, {width, 1}, C_BORDER)
		ui.draw_rect({0, 0}, {1, height}, C_BORDER)
		ui.draw_rect({width - 1, 0}, {1, height}, C_BORDER)

		ui.scope_at({12, (height - measured.y) * 0.5}, measured)
		ui.text(ui.id("header/badge/label"), measured, label, opts)
	}
}

draw_sidebar :: proc(view: int) -> int {
	next_view := view
	size := ui.get_size()

	ui.fill_rect(C_SIDEBAR)
	ui.draw_rect({size.x - 1, 0}, {1, size.y}, C_BORDER)

	{
		ui.padding({24, 16, 16, 16})
		area := ui.get_available_size()

		draw_text_line(
			ui.id("side/label"),
			{0, 0},
			{area.x, 16},
			"WORKSPACE",
			make_text_opts(FONT_BOLD, 10, C_TEXT_DIM),
		)

		nav_hover := ui.get(ui.id("nav/hover"), [NAV_COUNT]bool)
		nav_pressed := ui.get(ui.id("nav/pressed"), [NAV_COUNT]bool)

		for label, i in NAV_ITEMS {
			{
				ui.scope_at({0, 28 + f64(i) * 44}, {area.x, 36})

				if view == i {
					ui.fill_rect(C_NAV_ACTIVE)
					ui.draw_rect({0, 0}, {3, 36}, C_ACCENT)
				} else if nav_hover[i] {
					ui.fill_rect(C_NAV_HOVER)
				}

				ui.bind(.Hovered, &nav_hover[i])
				ui.bind(.Pressed, &nav_pressed[i])

				color := view == i ? C_TEXT : C_TEXT_MUTED
				draw_text_line(
					ui.id("nav/label", i),
					{16, 0},
					{area.x - 16, 36},
					label,
					make_text_opts(FONT_REGULAR, 14, color),
				)
			}
		}

		for i in 0 ..< NAV_COUNT {
			if nav_pressed[i] {
				next_view = i
				break
			}
		}

		controls_y := max(190, area.y - 166)
		{
			ui.scope_at({0, controls_y}, {area.x, 166})

			draw_text_line(
				ui.id("side/rendering"),
				{0, 0},
				{area.x, 16},
				"RENDERING",
				make_text_opts(FONT_BOLD, 10, C_TEXT_DIM),
			)

			scale_label := fmt.aprintf(
				"UI scale      %.2fx",
				app.scale.ui_scale,
				allocator = ui.get_temp_allocator(),
			)
			ssaa_label := fmt.aprintf(
				"Supersample   %.2fx",
				app.scale.render_scale,
				allocator = ui.get_temp_allocator(),
			)

			draw_text_line(
				ui.id("side/scale/label"),
				{0, 28},
				{area.x, 18},
				scale_label,
				make_text_opts(FONT_REGULAR, 12, C_TEXT_MUTED),
			)
			if draw_button(ui.id("side/scale/minus"), {0, 52}, {34, 28}, "-", SMALL_BUTTON) {
				app.pending_scale -= 0.25
			}
			if draw_button(ui.id("side/scale/plus"), {42, 52}, {34, 28}, "+", SMALL_BUTTON) {
				app.pending_scale += 0.25
			}

			draw_text_line(
				ui.id("side/ssaa/label"),
				{0, 92},
				{area.x, 18},
				ssaa_label,
				make_text_opts(FONT_REGULAR, 12, C_TEXT_MUTED),
			)
			if draw_button(ui.id("side/ssaa/minus"), {0, 116}, {34, 28}, "-", SMALL_BUTTON) {
				app.pending_render_scale -= 0.25
			}
			if draw_button(ui.id("side/ssaa/plus"), {42, 116}, {34, 28}, "+", SMALL_BUTTON) {
				app.pending_render_scale += 0.25
			}
		}
	}

	return next_view
}

draw_content :: proc(view: int) {
	ui.fill_rect(C_BG)

	{
		ui.padding({28, 28, 28, 28})
		area := ui.get_available_size()

		{
			ui.scope_at({0, 0}, {area.x, 64})
			draw_text_line(
				ui.id("page/title"),
				{0, 0},
				{area.x, 34},
				PAGE_TITLES[view],
				make_text_opts(FONT_BOLD, 26, C_TEXT),
			)
			draw_text_line(
				ui.id("page/sub"),
				{0, 38},
				{area.x, 22},
				PAGE_SUBS[view],
				make_text_opts(FONT_REGULAR, 13, C_TEXT_MUTED),
			)
		}

		rest := ui.Vec2{area.x, max(80, area.y - 82)}
		switch view {
		case 0:
			draw_dashboard({0, 82}, rest)
		case 1:
			draw_typography({0, 82}, rest)
		case 2:
			draw_scaling({0, 82}, rest)
		}
	}
}

draw_dashboard :: proc(pos, size: ui.Vec2) {
	ui.scope_at(pos, size)
	ui.grid_with_poly(
		&app.grid_offset,
		size,
		CARD_COUNT,
		{250, 158},
		{16, 16},
		app.cards,
		proc(i: int, cards: []Card_State) {
			draw_card(i, &cards[i])
		},
		{.Clip},
		{.Clip},
	)
}

draw_card :: proc(index: int, card: ^Card_State) {
	size := ui.get_size()
	accent := CARD_ACCENTS[index % len(CARD_ACCENTS)]

	bg := C_PANEL
	if card.pressed {
		bg = C_PANEL_PRESSED
	} else if card.hovered {
		bg = C_PANEL_HOVER
	}

	ui.fill_rect(bg)
	ui.draw_rect({0, 0}, {size.x, 1}, C_BORDER)
	ui.draw_rect({0, size.y - 1}, {size.x, 1}, C_BORDER)
	ui.draw_rect({0, 0}, {1, size.y}, C_BORDER)
	ui.draw_rect({size.x - 1, 0}, {1, size.y}, C_BORDER)
	ui.draw_rect({0, 0}, {size.x, 3}, accent)

	ui.bind(.Hovered, &card.hovered)
	ui.bind(.Pressed, &card.pressed)

	inner := ui.Vec2{size.x - 32, size.y - 38}

	{
		ui.scope_at({16, 22}, inner)

		draw_text_line(
			ui.id("card/title", index),
			{0, 0},
			{inner.x, 22},
			CARD_TITLES[index % len(CARD_TITLES)],
			make_text_opts(FONT_BOLD, 16, C_TEXT),
		)

		{
			ui.scope_at({0, 30}, {inner.x, max(0, inner.y - 48)})
			ui.text(
				ui.id("card/desc", index),
				ui.get_size(),
				CARD_DESCRIPTIONS[index % len(CARD_DESCRIPTIONS)],
				make_text_opts(FONT_REGULAR, 12, C_TEXT_MUTED, .Word, 3),
				{.Clip},
			)
		}

		tag := fmt.aprintf(
			"%02d  ·  %s",
			index,
			CARD_TAGS[index % len(CARD_TAGS)],
			allocator = ui.get_temp_allocator(),
		)
		draw_text_line(
			ui.id("card/tag", index),
			{0, max(0, inner.y - 16)},
			{inner.x, 16},
			tag,
			make_text_opts(FONT_REGULAR, 10, accent),
		)
	}
}

draw_typography :: proc(pos, size: ui.Vec2) {
	ui.scope_at(pos, size)

	left_w := size.x * 0.58
	gap := 16.0

	{
		ui.scope_at({0, 0}, {left_w, size.y})
		ui.fill_rect(C_PANEL)
		ui.draw_rect({0, 0}, {left_w, 1}, C_BORDER)
		ui.draw_rect({0, 0}, {1, size.y}, C_BORDER)
		ui.draw_rect({left_w - 1, 0}, {1, size.y}, C_BORDER)

		{
			ui.padding({24, 24, 24, 24})
			area := ui.get_available_size()

			draw_text_line(
				ui.id("typo/title"),
				{0, 0},
				{area.x, 22},
				"Word wrap + vertical scroll",
				make_text_opts(FONT_BOLD, 16, C_TEXT),
			)
			draw_text_line(
				ui.id("typo/hint"),
				{0, 24},
				{area.x, 18},
				"wheel over this panel",
				make_text_opts(FONT_REGULAR, 11, C_TEXT_DIM),
			)

			{
				ui.scope_at({0, 52}, {area.x, max(0, area.y - 52)})
				opts := make_text_opts(FONT_REGULAR, 15, C_TEXT_MUTED, .Word, 6)
				opts.scroll = .Y
				ui.text(ui.id("typo/body"), ui.get_size(), TYPO_BODY, opts, {.Clip})
			}
		}
	}

	{
		ui.scope_at({left_w + gap, 0}, {size.x - left_w - gap, size.y})
		ui.fill_rect(C_PANEL)
		ui.draw_rect({0, 0}, {size.x - left_w - gap, 1}, C_BORDER)
		ui.draw_rect({0, 0}, {1, size.y}, C_BORDER)
		ui.draw_rect({size.x - left_w - gap - 1, 0}, {1, size.y}, C_BORDER)

		{
			ui.padding({20, 20, 20, 20})
			area := ui.get_available_size()

			draw_text_line(
				ui.id("typo/sizes/title"),
				{0, 0},
				{area.x, 20},
				"RASTER SIZES",
				make_text_opts(FONT_BOLD, 10, C_TEXT_DIM),
			)

			sample_sizes := [?]int{11, 13, 15, 18, 22, 28, 36}

			for sample_size, i in sample_sizes {
				y := 28 + f64(i) * 48
				if y + 46 > area.y do break

				label := fmt.aprintf(
					"%d px",
					sample_size,
					allocator = ui.get_temp_allocator(),
				)

				draw_text_line(
					ui.id("typo/sample", i),
					{0, y},
					{area.x - 66, 44},
					"Aa 0123",
					make_text_opts(FONT_REGULAR, f64(sample_size), C_TEXT),
				)
				draw_text_line(
					ui.id("typo/size", i),
					{area.x - 62, y},
					{62, 44},
					label,
					make_text_opts(FONT_REGULAR, 11, C_TEXT_DIM),
					.Right,
				)

				ui.draw_rect({0, y + 45}, {area.x, 1}, C_BORDER)
			}
		}
	}
}

draw_scaling :: proc(pos, size: ui.Vec2) {
	ui.scope_at(pos, size)

	left_w := size.x * 0.46
	gap := 16.0

	{
		ui.scope_at({0, 0}, {left_w, size.y})
		ui.fill_rect(C_PANEL)
		ui.draw_rect({0, 0}, {left_w, 1}, C_BORDER)
		ui.draw_rect({0, 0}, {1, size.y}, C_BORDER)
		ui.draw_rect({left_w - 1, 0}, {1, size.y}, C_BORDER)

		{
			ui.padding({24, 24, 24, 24})
			area := ui.get_available_size()

			draw_text_line(
				ui.id("scaling/title"),
				{0, 0},
				{area.x, 22},
				"How it works",
				make_text_opts(FONT_BOLD, 16, C_TEXT),
			)

			body := "The UI is laid out in logical pixels. The backend renders it into a texture that is larger than the window by the supersampling factor, then downsamples it. Text is rasterized at the final physical size, not at the logical size, which is why it stays sharp when the scale changes."
			{
				ui.scope_at({0, 26}, {area.x, 118})
				ui.text(
					ui.id("scaling/body"),
					ui.get_size(),
					body,
					make_text_opts(FONT_REGULAR, 12, C_TEXT_MUTED, .Word, 4),
					{.Clip},
				)
			}

			values := [?]struct {
				label: string,
				value: string,
			} {
				{"window", fmt.aprintf("%d x %d", int(rl.GetScreenWidth()), int(rl.GetScreenHeight()), allocator = ui.get_temp_allocator())},
				{"logical", fmt.aprintf("%.0f x %.0f", app.scale.logical_size.x, app.scale.logical_size.y, allocator = ui.get_temp_allocator())},
				{"target", fmt.aprintf("%d x %d", app.scale.target.texture.width, app.scale.target.texture.height, allocator = ui.get_temp_allocator())},
				{"pixels / unit", fmt.aprintf("%.2f", app.scale.ppu, allocator = ui.get_temp_allocator())},
				{"ui scale", fmt.aprintf("%.2fx", app.scale.ui_scale, allocator = ui.get_temp_allocator())},
				{"supersample", fmt.aprintf("%.2fx", app.scale.render_scale, allocator = ui.get_temp_allocator())},
			}

			for value, i in values {
				y := 160 + f64(i) * 26
				if y + 24 > area.y do break

				draw_text_line(
					ui.id("scaling/label", i),
					{0, y},
					{area.x * 0.52, 24},
					value.label,
					make_text_opts(FONT_REGULAR, 12, C_TEXT_DIM),
				)
				draw_text_line(
					ui.id("scaling/value", i),
					{area.x * 0.52, y},
					{area.x * 0.48, 24},
					value.value,
					make_text_opts(FONT_BOLD, 12, C_TEXT),
					.Right,
				)
				ui.draw_rect({0, y + 25}, {area.x, 1}, C_BORDER)
			}
		}
	}

	{
		ui.scope_at({left_w + gap, 0}, {size.x - left_w - gap, size.y})
		ui.fill_rect(C_PANEL)
		ui.draw_rect({0, 0}, {size.x - left_w - gap, 1}, C_BORDER)
		ui.draw_rect({0, 0}, {1, size.y}, C_BORDER)
		ui.draw_rect({size.x - left_w - gap - 1, 0}, {1, size.y}, C_BORDER)

		{
			ui.padding({20, 20, 20, 20})
			area := ui.get_available_size()

			draw_text_line(
				ui.id("scaling/pattern/title"),
				{0, 0},
				{area.x, 18},
				"1 LOGICAL PX GRID · 8 PX PITCH",
				make_text_opts(FONT_BOLD, 10, C_TEXT_DIM),
			)

			pattern_h := max(1, area.y - 28)
			{
				ui.scope_at({0, 28}, {area.x, pattern_h})
				ui.fill_rect(C_BG)

				x: f64 = 0
				for x < area.x {
					ui.draw_rect({x, 0}, {1, pattern_h}, C_ACCENT_DIM)
					x += 8
				}

				y: f64 = 0
				for y < pattern_h {
					ui.draw_rect({0, y}, {area.x, 1}, C_ACCENT_DIM)
					y += 8
				}

				ui.draw_rect({0, 0}, {area.x, 1}, C_ACCENT)
				ui.draw_rect({0, pattern_h - 1}, {area.x, 1}, C_ACCENT)
				ui.draw_rect({0, 0}, {1, pattern_h}, C_ACCENT)
				ui.draw_rect({area.x - 1, 0}, {1, pattern_h}, C_ACCENT)

				draw_text_line(
					ui.id("scaling/pattern/caption"),
					{8, 8},
					{area.x - 16, 18},
					"edges should stay one physical pixel wide",
					make_text_opts(FONT_REGULAR, 10, C_TEXT_MUTED),
				)
			}
		}
	}
}

draw_footer :: proc() {
	ui.fill_rect(C_FOOTER)
	ui.draw_rect({0, 0}, {ui.get_size().x, 1}, C_BORDER)

	{
		ui.padding({0, 14, 0, 14})
		area := ui.get_available_size()

		fps := fmt.aprintf(
			"%d fps  ·  %.2f ms  ·  %d scopes",
			rl.GetFPS(),
			f64(rl.GetFrameTime()) * 1000,
			ui.ctx.scope_count,
			allocator = ui.get_temp_allocator(),
		)
		draw_text_line(
			ui.id("footer/stats"),
			{0, 0},
			{area.x * 0.5, 28},
			fps,
			make_text_opts(FONT_REGULAR, 11, C_TEXT_DIM),
		)

		draw_text_line(
			ui.id("footer/help"),
			{area.x * 0.5, 0},
			{area.x * 0.5, 28},
			"- / =  scale      [ / ]  supersample      R  reset      D  profiler",
			make_text_opts(FONT_REGULAR, 11, C_TEXT_DIM),
			.Right,
		)
	}
}
