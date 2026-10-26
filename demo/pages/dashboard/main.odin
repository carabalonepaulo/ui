package dashboard

import ".."
import "../../../ui"

CARD_COUNT :: 60

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
	"Draw calls are batched and the UI never allocates per frame outside its arena.",
}

CARD_TAGS := [?]string{"layout", "core", "layout", "layout", "scroll", "scroll", "state", "text", "overlay", "render", "input", "perf"}

CARD_ACCENTS := [?]ui.Color{
	{94, 234, 212, 255},
	{129, 140, 248, 255},
	{244, 114, 182, 255},
	{251, 191, 36, 255},
}

Card_State :: struct {
	hovered: bool,
	pressed: bool,
}

State :: struct {
	ctx:          pages.Context,
	font_bold:    ui.Font,
	font_regular: ui.Font,
	cards:        []Card_State,
	offset:       f64,
}

create :: proc() -> pages.Interface {
	return pages.Interface {
		self      = new(State),
		page      = .Dashboard,
		label     = "Dashboard",
		on_ready  = auto_cast on_ready,
		on_enter  = auto_cast on_enter,
		on_update = auto_cast on_update,
		on_exit   = auto_cast on_exit,
		destroy   = auto_cast destroy,
	}
}

destroy :: proc(self: ^State) {
	delete(self.cards)
	free(self)
}

on_ready :: proc(self: ^State, ctx: pages.Context) {
	self.ctx = ctx
	self.font_bold = ctx.load_font("bold", 16)
	self.font_regular = ctx.load_font("regular", 12)
	self.cards = make([]Card_State, CARD_COUNT)
}

on_enter :: proc(self: ^State, payload: ^pages.Dashboard_Payload) {
	for &card in self.cards {
		card.hovered = false
		card.pressed = false
	}
}

on_update :: proc(self: ^State) {
	view(self)
}

on_exit :: proc(self: ^State) {
	for &card in self.cards {
		card.hovered = false
		card.pressed = false
	}
}
