package ui

draw_rect :: proc(x, y, w, h: f32, color: Color) {
	assert(ctx.current_scope != -1, "invalid scope")

	pos := to_screen_pos({x, y})
	ctx.callbacks.draw_rect(pos.x, pos.y, w, h, color)
}

draw_text :: proc(font: Font, text: string, x, y, size, spacing: f32, color: Color) {
	assert(ctx.current_scope != -1, "invalid scope")

	pos := to_screen_pos({x, y})
	ctx.callbacks.draw_text(font, text, pos.x, pos.y, size, spacing, color)
}

