package demo

import "core:fmt"
import "kit"
import "pages"
import "pages/dashboard"
import "pages/scaling"
import "pages/typography"
import ui "../ui"
import rl "vendor:raylib"

// Layout constants are logical pixels.
HEADER_H :: 56
FOOTER_H :: 28
SIDEBAR_W :: 224

// Registration order is also the --view order. Add a constructor here and the
// page becomes available to the shell and to the navbar, no core changes.
PAGE_CTORS :: [?]proc() -> pages.Interface {
	dashboard.create,
	typography.create,
	scaling.create,
}

PAGE_ORDER :: [?]pages.Page{.Dashboard, .Typography, .Scaling}

Next_Page :: struct {
	page: pages.Page,
	ud:   rawptr,
}

App :: struct {
	renderer:             Renderer,
	scale:                UIScale,
	// Page framework.
	page_list:            [len(PAGE_CTORS)]pages.Interface,
	current_page:         pages.Page,
	next_page:            Maybe(Next_Page),
	ctx:                  pages.Context,
	scroll_modifier:      f64,
	// Shell resources.
	font_regular:         ui.Font,
	font_bold:            ui.Font,
	// Backend state.
	start_page_index:     int,
	pending_scale:        f64,
	pending_render_scale: f64,
	wheel:                Smooth_Wheel,
	screenshot_path:      string,
	screenshot_frames:    int,
}

app: App

app_init :: proc() {
	app.ctx = pages.Context {
		go_to               = app_go_to,
		set_scroll_modifier = app_set_scroll_modifier,
		load_font           = app_load_font,
		scale_info          = app_scale_info,
	}

	ctors := PAGE_CTORS
	for i in 0 ..< len(PAGE_CTORS) {
		app.page_list[i] = ctors[i]()
		app.page_list[i].on_ready(app.page_list[i].self, app.ctx)
	}

	app.font_regular = renderer_get_font(&app.renderer, "regular")
	app.font_bold = renderer_get_font(&app.renderer, "bold")

	order := PAGE_ORDER
	index := clamp(app.start_page_index, 0, len(PAGE_ORDER) - 1)
	app.current_page = order[index]
	if page := app_find_page(app.current_page); page != nil {
		page.on_enter(page.self, nil)
	}
}

app_deinit :: proc() {
	for i in 0 ..< len(app.page_list) {
		app.page_list[i].destroy(app.page_list[i].self)
	}
}

app_update :: proc() {
	if page := app_find_page(app.current_page); page != nil {
		page.on_update(page.self)
	}
}

app_go_to :: proc(page: pages.Page, ud: rawptr = nil) {
	app.next_page = Next_Page{page, ud}
}

app_set_scroll_modifier :: proc(modifier: f32) {
	app.scroll_modifier = f64(modifier)
}

app_load_font :: proc(name: string, size: f64) -> ui.Font {
	// Fontstash rasterizes on demand, so the size hint is not needed here. A
	// backend that bakes atlases per size would use it.
	_ = size
	return renderer_get_font(&app.renderer, name)
}

app_scale_info :: proc() -> pages.Scale_Info {
	return {
		window_size = {int(rl.GetScreenWidth()), int(rl.GetScreenHeight())},
		logical_size = app.scale.logical_size,
		target_size = {
			int(app.scale.target.texture.width),
			int(app.scale.target.texture.height),
		},
		ui_scale = app.scale.ui_scale,
		render_scale = app.scale.render_scale,
		pixels_per_unit = app.scale.ppu,
	}
}

app_find_page :: proc(page: pages.Page) -> ^pages.Interface {
	for &iface in app.page_list {
		if iface.page == page {
			return &iface
		}
	}
	return nil
}

app_change_page :: proc(page: pages.Page, ud: rawptr = nil) {
	if app.current_page == page do return

	if current := app_find_page(app.current_page); current != nil {
		current.on_exit(current.self)
	}

	if next := app_find_page(page); next != nil {
		next.on_enter(next.self, ud)
		app.current_page = page
	}
}

// Apply the page queued by go_to. Kept inside the UI frame so payloads
// allocated in the frame arena (the `ud` pointer) are still alive.
app_apply_pending_page :: proc() {
	if next, ok := app.next_page.(Next_Page); ok {
		app.next_page = nil
		app_change_page(next.page, next.ud)
	}
}

app_draw :: proc(ud: rawptr) {
	size := app.scale.logical_size

	ui.scope(size)
	ui.fill_rect(kit.C_BG)

	{
		ui.scope_at({0, 0}, {size.x, HEADER_H})
		draw_header()
	}
	{
		ui.scope_at({0, HEADER_H}, {SIDEBAR_W, size.y - HEADER_H - FOOTER_H})
		draw_sidebar()
	}
	{
		ui.scope_at({SIDEBAR_W, HEADER_H}, {size.x - SIDEBAR_W, size.y - HEADER_H - FOOTER_H})
		ui.fill_rect(kit.C_BG)
		app_update()
	}
	{
		ui.scope_at({0, size.y - FOOTER_H}, {size.x, FOOTER_H})
		draw_footer()
	}

	debug := ui.get(ui.id("app/debug"), bool)
	if rl.IsKeyPressed(.D) {
		debug^ = !(debug^)
	}
	if debug^ {
		ui.popup({0, 0}, size, ui.profiler)
	}

	app_apply_pending_page()
}

draw_header :: proc() {
	ui.fill_rect(kit.C_HEADER)
	ui.draw_rect({0, HEADER_H - 1}, {ui.get_size().x, 1}, kit.C_BORDER)

	{
		ui.padding({0, 22, 0, 22})
		row := ui.flex(
			ui.get_available_size(),
			.X,
			{{.Absolute, 260}, {.Flex, 1}, {.Absolute, 340}},
			gap = 18,
		)

		if ui.next(&row) {
			kit.draw_text_line(
				ui.id("header/title"),
				{},
				ui.get_size(),
				"ODIN UI",
				kit.make_text_opts(app.font_bold, 22, kit.C_TEXT),
			)
		}
		if ui.next(&row) {
			kit.draw_text_line(
				ui.id("header/subtitle"),
				{},
				ui.get_size(),
				"immediate-mode layout · explicit sizes · pages",
				kit.make_text_opts(app.font_regular, 12, kit.C_TEXT_DIM),
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
	opts := kit.make_text_opts(app.font_bold, 11, kit.C_ACCENT)

	measured := ui.measure_text(ui.id("header/badge/label"), {ui.AUTO, ui.AUTO}, label, &opts)
	width := measured.x + 24
	height := measured.y + 12
	x := area.x - width
	y := (area.y - height) * 0.5

	{
		ui.scope_at({x, y}, {width, height})
		ui.fill_rect(kit.C_BADGE_BG)
		ui.draw_rect({0, 0}, {width, 1}, kit.C_BORDER)
		ui.draw_rect({0, height - 1}, {width, 1}, kit.C_BORDER)
		ui.draw_rect({0, 0}, {1, height}, kit.C_BORDER)
		ui.draw_rect({width - 1, 0}, {1, height}, kit.C_BORDER)

		ui.scope_at({12, (height - measured.y) * 0.5}, measured)
		ui.text(ui.id("header/badge/label"), measured, label, opts)
	}
}

draw_sidebar :: proc() {
	size := ui.get_size()

	ui.fill_rect(kit.C_SIDEBAR)
	ui.draw_rect({size.x - 1, 0}, {1, size.y}, kit.C_BORDER)

	{
		ui.padding({24, 16, 16, 16})
		area := ui.get_available_size()

		kit.draw_text_line(
			ui.id("side/label"),
			{0, 0},
			{area.x, 16},
			"WORKSPACE",
			kit.make_text_opts(app.font_bold, 10, kit.C_TEXT_DIM),
		)

		for iface, i in app.page_list {
			{
				hover := ui.get(ui.id("app/nav/hover", iface.page), bool)
				press := ui.get(ui.id("app/nav/pressed", iface.page), bool)

				ui.scope_at({0, 28 + f64(i) * 44}, {area.x, 36})

				if app.current_page == iface.page {
					ui.fill_rect(kit.C_NAV_ACTIVE)
					ui.draw_rect({0, 0}, {3, 36}, kit.C_ACCENT)
				} else if hover^ {
					ui.fill_rect(kit.C_NAV_HOVER)
				}

				ui.bind(.Hovered, hover)
				ui.bind(.Pressed, press)

				color := app.current_page == iface.page ? kit.C_TEXT : kit.C_TEXT_MUTED
				kit.draw_text_line(
					ui.id("app/nav/label", iface.page),
					{16, 0},
					{area.x - 16, 36},
					iface.label,
					kit.make_text_opts(app.font_regular, 14, color),
				)

				if press^ {
					app_go_to(iface.page)
				}
			}
		}

		controls_y := max(190, area.y - 166)
		{
			ui.scope_at({0, controls_y}, {area.x, 166})

			kit.draw_text_line(
				ui.id("side/rendering"),
				{0, 0},
				{area.x, 16},
				"RENDERING",
				kit.make_text_opts(app.font_bold, 10, kit.C_TEXT_DIM),
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

			kit.draw_text_line(
				ui.id("side/scale/label"),
				{0, 28},
				{area.x, 18},
				scale_label,
				kit.make_text_opts(app.font_regular, 12, kit.C_TEXT_MUTED),
			)
			if kit.draw_button(
				ui.id("side/scale/minus"),
				{0, 52},
				{34, 28},
				"-",
				kit.SMALL_BUTTON,
				app.font_regular,
			) {
				app.pending_scale -= 0.25
			}
			if kit.draw_button(
				ui.id("side/scale/plus"),
				{42, 52},
				{34, 28},
				"+",
				kit.SMALL_BUTTON,
				app.font_regular,
			) {
				app.pending_scale += 0.25
			}

			kit.draw_text_line(
				ui.id("side/ssaa/label"),
				{0, 92},
				{area.x, 18},
				ssaa_label,
				kit.make_text_opts(app.font_regular, 12, kit.C_TEXT_MUTED),
			)
			if kit.draw_button(
				ui.id("side/ssaa/minus"),
				{0, 116},
				{34, 28},
				"-",
				kit.SMALL_BUTTON,
				app.font_regular,
			) {
				app.pending_render_scale -= 0.25
			}
			if kit.draw_button(
				ui.id("side/ssaa/plus"),
				{42, 116},
				{34, 28},
				"+",
				kit.SMALL_BUTTON,
				app.font_regular,
			) {
				app.pending_render_scale += 0.25
			}
		}
	}
}

draw_footer :: proc() {
	ui.fill_rect(kit.C_FOOTER)
	ui.draw_rect({0, 0}, {ui.get_size().x, 1}, kit.C_BORDER)

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
		kit.draw_text_line(
			ui.id("footer/stats"),
			{0, 0},
			{area.x * 0.5, 28},
			fps,
			kit.make_text_opts(app.font_regular, 11, kit.C_TEXT_DIM),
		)

		kit.draw_text_line(
			ui.id("footer/help"),
			{area.x * 0.5, 0},
			{area.x * 0.5, 28},
			"- / =  scale      [ / ]  supersample      R  reset      D  profiler",
			kit.make_text_opts(app.font_regular, 11, kit.C_TEXT_DIM),
			.Right,
		)
	}
}
