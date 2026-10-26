package kit

import ui "../../ui"

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
	font: ui.Font,
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

	opts := make_text_opts(font, text_size, style.text)
	draw_text_line(ui.id(uid, "label"), {}, size, label, opts, .Center)

	return pressed^
}

// Shared page heading. Call after the content's outer padding; it consumes the
// top 64 logical pixels of the current available area. Pages place their body
// at y = 82.
draw_page_header :: proc(
	uid: ui.Id,
	title, subtitle: string,
	font_title, font_subtitle: ui.Font,
) {
	size := ui.get_available_size()
	draw_text_line(
		ui.id(uid, "title"),
		{0, 0},
		{size.x, 34},
		title,
		make_text_opts(font_title, 26, C_TEXT),
	)
	draw_text_line(
		ui.id(uid, "subtitle"),
		{0, 38},
		{size.x, 22},
		subtitle,
		make_text_opts(font_subtitle, 13, C_TEXT_MUTED),
	)
}
