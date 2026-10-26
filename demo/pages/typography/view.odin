package typography

import ".."
import "../../kit"
import "../../../ui"
import "core:fmt"

TYPO_BODY :: "The UI library has no layout engine that guesses. You declare a scope, tell it how big it is, and then place things inside it. That sounds tedious, and it is, but it also means every frame costs the same and every position is known before it is drawn. Text is measured through the backend, wrapped by the library, and cached by a hash of its contents and options. Scroll offsets are bound to f64 values in the hashed store, so the same code can drive a list of ten items or a list of a million. The demo below is a single text scope: it wraps on word boundaries, clips to its rectangle, and scrolls vertically with the wheel."

view :: proc(self: ^State) {
	ui.padding({28, 28, 28, 28})
	area := ui.get_available_size()

	kit.draw_page_header(
		ui.id("page/typography"),
		"Typography",
		"Text rasterized at the physical pixel size, wrapped and scrolled by the library.",
		self.font_bold,
		self.font_regular,
	)

	rest := ui.Vec2{area.x, max(80, area.y - 82)}
	{
		ui.scope_at({0, 82}, rest)
		draw_panels(self, rest)
	}
}

draw_panels :: proc(self: ^State, size: ui.Vec2) {
	left_w := size.x * 0.58
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
				ui.id("typo/title"),
				{0, 0},
				{area.x, 22},
				"Word wrap + vertical scroll",
				kit.make_text_opts(self.font_bold, 16, kit.C_TEXT),
			)
			kit.draw_text_line(
				ui.id("typo/hint"),
				{0, 24},
				{area.x, 18},
				"wheel over this panel",
				kit.make_text_opts(self.font_regular, 11, kit.C_TEXT_DIM),
			)

			{
				ui.scope_at({0, 52}, {area.x, max(0, area.y - 52)})
				opts := kit.make_text_opts(self.font_regular, 15, kit.C_TEXT_MUTED, .Word, 6)
				opts.scroll = .Y
				ui.text(ui.id("typo/body"), ui.get_size(), TYPO_BODY, opts, {.Clip})
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
				ui.id("typo/sizes/title"),
				{0, 0},
				{area.x, 20},
				"RASTER SIZES",
				kit.make_text_opts(self.font_bold, 10, kit.C_TEXT_DIM),
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

				kit.draw_text_line(
					ui.id("typo/sample", i),
					{0, y},
					{area.x - 66, 44},
					"Aa 0123",
					kit.make_text_opts(self.font_regular, f64(sample_size), kit.C_TEXT),
				)
				kit.draw_text_line(
					ui.id("typo/size", i),
					{area.x - 62, y},
					{62, 44},
					label,
					kit.make_text_opts(self.font_regular, 11, kit.C_TEXT_DIM),
					.Right,
				)

				ui.draw_rect({0, y + 45}, {area.x, 1}, kit.C_BORDER)
			}
		}
	}
}
