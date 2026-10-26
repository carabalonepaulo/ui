package dashboard

import ".."
import "../../kit"
import "../../../ui"
import "core:fmt"

view :: proc(self: ^State) {
	ui.padding({28, 28, 28, 28})
	area := ui.get_available_size()

	kit.draw_page_header(
		ui.id("page/dashboard"),
		"Dashboard",
		"Immediate-mode cards in a virtualized grid. Hover and press are bound per card.",
		self.font_bold,
		self.font_regular,
	)

	rest := ui.Vec2{area.x, max(80, area.y - 82)}
	{
		ui.scope_at({0, 82}, rest)
		ui.grid_with_poly(
			&self.offset,
			rest,
			CARD_COUNT,
			{250, 158},
			{16, 16},
			self,
			proc(i: int, self: ^State) {
				draw_card(self, i)
			},
			{.Clip},
			{.Clip},
		)
	}
}

draw_card :: proc(self: ^State, index: int) {
	size := ui.get_size()
	card := &self.cards[index]
	accent := CARD_ACCENTS[index % len(CARD_ACCENTS)]

	bg := kit.C_PANEL
	if card.pressed {
		bg = kit.C_PANEL_PRESSED
	} else if card.hovered {
		bg = kit.C_PANEL_HOVER
	}

	ui.fill_rect(bg)
	ui.draw_rect({0, 0}, {size.x, 1}, kit.C_BORDER)
	ui.draw_rect({0, size.y - 1}, {size.x, 1}, kit.C_BORDER)
	ui.draw_rect({0, 0}, {1, size.y}, kit.C_BORDER)
	ui.draw_rect({size.x - 1, 0}, {1, size.y}, kit.C_BORDER)
	ui.draw_rect({0, 0}, {size.x, 3}, accent)

	ui.bind(.Hovered, &card.hovered)
	ui.bind(.Pressed, &card.pressed)

	inner := ui.Vec2{size.x - 32, size.y - 38}

	{
		ui.scope_at({16, 22}, inner)

		kit.draw_text_line(
			ui.id("card/title", index),
			{0, 0},
			{inner.x, 22},
			CARD_TITLES[index % len(CARD_TITLES)],
			kit.make_text_opts(self.font_bold, 16, kit.C_TEXT),
		)

		{
			ui.scope_at({0, 30}, {inner.x, max(0, inner.y - 48)})
			ui.text(
				ui.id("card/desc", index),
				ui.get_size(),
				CARD_DESCRIPTIONS[index % len(CARD_DESCRIPTIONS)],
				kit.make_text_opts(self.font_regular, 12, kit.C_TEXT_MUTED, .Word, 3),
				{.Clip},
			)
		}

		tag := fmt.aprintf(
			"%02d  ·  %s",
			index,
			CARD_TAGS[index % len(CARD_TAGS)],
			allocator = ui.get_temp_allocator(),
		)
		kit.draw_text_line(
			ui.id("card/tag", index),
			{0, max(0, inner.y - 16)},
			{inner.x, 16},
			tag,
			kit.make_text_opts(self.font_regular, 10, accent),
		)
	}
}
