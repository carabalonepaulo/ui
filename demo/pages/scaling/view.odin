package scaling

import ".."
import "../../kit"
import "../../../ui"
import "core:fmt"

view :: proc(self: ^State) {
	ui.padding({28, 28, 28, 28})
	area := ui.get_available_size()

	kit.draw_page_header(
		ui.id("page/scaling"),
		"Scaling",
		"Render above the destination resolution, then downsample for crisp UI at any scale.",
		self.font_bold,
		self.font_regular,
	)

	rest := ui.Vec2{area.x, max(80, area.y - 82)}
	{
		ui.scope_at({0, 82}, rest)
		draw_panels(self, rest, self.ctx.scale_info())
	}
}

draw_panels :: proc(self: ^State, size: ui.Vec2, info: pages.Scale_Info) {
	left_w := size.x * 0.46
	gap := 16.0

	{
		ui.scope_at({0, 0}, {left_w, size.y})
		ui.fill_rect(kit.C_PANEL)
		ui.draw_rect({0, 0}, {left_w, 1}, kit.C_BORDER)
		ui.draw_rect({0, 0}, {1, size.y}, kit.C_BORDER)
		ui.draw_rect({left_w - 1, 0}, {1, size.y}, kit.C_BORDER)

		{
			ui.padding({24, 24, 24, 24})
			area := ui.get_available_size()

			kit.draw_text_line(
				ui.id("scaling/title"),
				{0, 0},
				{area.x, 22},
				"How it works",
				kit.make_text_opts(self.font_bold, 16, kit.C_TEXT),
			)

			body := "The UI is laid out in logical pixels. The backend renders it into a texture that is larger than the window by the supersampling factor, then downsamples it. Text is rasterized at the final physical size, not at the logical size, which is why it stays sharp when the scale changes."
			{
				ui.scope_at({0, 26}, {area.x, 118})
				ui.text(
					ui.id("scaling/body"),
					ui.get_size(),
					body,
					kit.make_text_opts(self.font_regular, 12, kit.C_TEXT_MUTED, .Word, 4),
					{.Clip},
				)
			}

			values := [?]struct {
				label: string,
				value: string,
			} {
				{"window", fmt.aprintf("%d x %d", info.window_size.x, info.window_size.y, allocator = ui.get_temp_allocator())},
				{"logical", fmt.aprintf("%.0f x %.0f", info.logical_size.x, info.logical_size.y, allocator = ui.get_temp_allocator())},
				{"target", fmt.aprintf("%d x %d", info.target_size.x, info.target_size.y, allocator = ui.get_temp_allocator())},
				{"pixels / unit", fmt.aprintf("%.2f", info.pixels_per_unit, allocator = ui.get_temp_allocator())},
				{"ui scale", fmt.aprintf("%.2fx", info.ui_scale, allocator = ui.get_temp_allocator())},
				{"supersample", fmt.aprintf("%.2fx", info.render_scale, allocator = ui.get_temp_allocator())},
			}

			for value, i in values {
				y := 160 + f64(i) * 26
				if y + 24 > area.y do break

				kit.draw_text_line(
					ui.id("scaling/label", i),
					{0, y},
					{area.x * 0.52, 24},
					value.label,
					kit.make_text_opts(self.font_regular, 12, kit.C_TEXT_DIM),
				)
				kit.draw_text_line(
					ui.id("scaling/value", i),
					{area.x * 0.52, y},
					{area.x * 0.48, 24},
					value.value,
					kit.make_text_opts(self.font_bold, 12, kit.C_TEXT),
					.Right,
				)
				ui.draw_rect({0, y + 25}, {area.x, 1}, kit.C_BORDER)
			}
		}
	}

	{
		right_w := size.x - left_w - gap
		ui.scope_at({left_w + gap, 0}, {right_w, size.y})
		ui.fill_rect(kit.C_PANEL)
		ui.draw_rect({0, 0}, {right_w, 1}, kit.C_BORDER)
		ui.draw_rect({0, 0}, {1, size.y}, kit.C_BORDER)
		ui.draw_rect({right_w - 1, 0}, {1, size.y}, kit.C_BORDER)

		{
			ui.padding({20, 20, 20, 20})
			area := ui.get_available_size()

			kit.draw_text_line(
				ui.id("scaling/pattern/title"),
				{0, 0},
				{area.x, 18},
				"1 LOGICAL PX GRID · 8 PX PITCH",
				kit.make_text_opts(self.font_bold, 10, kit.C_TEXT_DIM),
			)

			pattern_h := max(1, area.y - 28)
			{
				ui.scope_at({0, 28}, {area.x, pattern_h})
				ui.fill_rect(kit.C_BG)

				x: f64 = 0
				for x < area.x {
					ui.draw_rect({x, 0}, {1, pattern_h}, kit.C_ACCENT_DIM)
					x += 8
				}

				y: f64 = 0
				for y < pattern_h {
					ui.draw_rect({0, y}, {area.x, 1}, kit.C_ACCENT_DIM)
					y += 8
				}

				ui.draw_rect({0, 0}, {area.x, 1}, kit.C_ACCENT)
				ui.draw_rect({0, pattern_h - 1}, {area.x, 1}, kit.C_ACCENT)
				ui.draw_rect({0, 0}, {1, pattern_h}, kit.C_ACCENT)
				ui.draw_rect({area.x - 1, 0}, {1, pattern_h}, kit.C_ACCENT)

				kit.draw_text_line(
					ui.id("scaling/pattern/caption"),
					{8, 8},
					{area.x - 16, 18},
					"edges should stay one physical pixel wide",
					kit.make_text_opts(self.font_regular, 10, kit.C_TEXT_MUTED),
				)
			}
		}
	}
}
