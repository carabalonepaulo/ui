package ui

draw_rect :: proc(pos: Vec2, size: Vec2, color: Color) {
	assert(ctx.current_scope != -1, "invalid scope")

	pos := to_screen_pos(pos)
	ctx.callbacks.draw_rect(f32(pos.x), f32(pos.y), f32(size.x), f32(size.y), color)
}

draw_text :: proc(font: Font, text: string, pos: Vec2, size, spacing: f64, color: Color) {
	assert(ctx.current_scope != -1, "invalid scope")

	pos := to_screen_pos(pos)
	ctx.callbacks.draw_text(font, text, f32(pos.x), f32(pos.y), f32(size), f32(spacing), color)
}

fill_rect :: proc(color: Color) {
	assert(ctx.current_scope != -1, "invalid scope")

	pos := to_screen_pos({0, 0})
	size := get_available_size()
	ctx.callbacks.draw_rect(f32(pos.x), f32(pos.y), f32(size.x), f32(size.y), color)
}

