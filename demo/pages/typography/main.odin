package typography

import ".."
import "../../../ui"

State :: struct {
	ctx:          pages.Context,
	font_bold:    ui.Font,
	font_regular: ui.Font,
}

create :: proc() -> pages.Interface {
	return pages.Interface {
		self      = new(State),
		page      = .Typography,
		label     = "Typography",
		on_ready  = auto_cast on_ready,
		on_enter  = auto_cast on_enter,
		on_update = auto_cast on_update,
		on_exit   = auto_cast on_exit,
		destroy   = auto_cast destroy,
	}
}

destroy :: proc(self: ^State) {
	free(self)
}

on_ready :: proc(self: ^State, ctx: pages.Context) {
	self.ctx = ctx
	self.font_bold = ctx.load_font("bold", 16)
	self.font_regular = ctx.load_font("regular", 15)
}

on_enter :: proc(self: ^State, payload: ^pages.Typography_Payload) {}

on_update :: proc(self: ^State) {
	view(self)
}

on_exit :: proc(self: ^State) {}
