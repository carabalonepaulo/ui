package ui

draw_rect :: proc(x, y, w, h: f32, color: Color) {
	assert(ctx.current_scope != -1, "invalid scope")

	scope := get_scope()
	x := scope.screen_pos[0] + x
	y := scope.screen_pos[1] + y
	ctx.callbacks.draw_rect(x, y, w, h, color)
}

draw_text :: proc(font: Font, text: string, x, y, size, spacing: f32, color: Color) {
	assert(ctx.current_scope != -1, "invalid scope")

	scope := get_scope()
	x := scope.screen_pos[0] + x
	y := scope.screen_pos[1] + y
	ctx.callbacks.draw_text(font, text, x, y, size, spacing, color)
}

