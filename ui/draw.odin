package ui

draw_rect :: proc(pos: Vec2, size: Vec2, color: Color) {
	assert(ctx.current_scope != -1, "invalid scope")

	pos := to_screen_pos(pos)
	ctx.callbacks.draw_rect(pos.x, pos.y, size.x, size.y, color)
}

draw_text :: proc(font: Font, text: string, pos: Vec2, size, spacing: f32, color: Color) {
	assert(ctx.current_scope != -1, "invalid scope")

	pos := to_screen_pos(pos)
	ctx.callbacks.draw_text(font, text, pos.x, pos.y, size, spacing, color)
}

fill_rect :: proc(color: Color) {
	assert(ctx.current_scope != -1, "invalid scope")

	pos := to_screen_pos({0, 0})
	size := get_available_size()
	ctx.callbacks.draw_rect(pos.x, pos.y, size.x, size.y, color)
}

