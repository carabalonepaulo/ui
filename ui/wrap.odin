package ui

Wrap :: struct {
	content_scope: int,
	cursor:        Vec2,
	line_height:   f32,
	usable_size:   Vec2,
	gap:           Vec2,
}

begin_wrap :: proc(size: Vec2, gap: Vec2 = {0, 0}, padding: [4]f32 = {0, 0, 0, 0}) -> Wrap {
	begin_scope(size)

	container := get_scope()
	container.cursor = {padding[3], padding[0]}

	usable_size := Vec2{size.x - (padding[1] + padding[3]), size.y - (padding[0] + padding[2])}

	begin_scope(usable_size, {.Clip})

	return Wrap {
		content_scope = ctx.current_scope,
		cursor = {},
		line_height = 0,
		usable_size = usable_size,
		gap = gap,
	}
}

@(private = "file")
end_wrap_child :: proc(state: ^Wrap, _: Vec2, success: bool) {
	if success do end_scope()
}

@(deferred_in_out = end_wrap_child)
wrap_next :: proc(state: ^Wrap, item_size: Vec2) -> bool {
	content := &ctx.buffer[state.content_scope]

	if state.cursor.x > 0 && state.cursor.x + item_size.x > state.usable_size.x {
		state.cursor.x = 0
		state.cursor.y += state.line_height + state.gap.y
		state.line_height = 0
	}

	content.cursor = state.cursor

	begin_scope(item_size)

	state.cursor.x += item_size.x + state.gap.x
	state.line_height = max(state.line_height, item_size.y)

	content.content_size.x = max(content.content_size.x, state.cursor.x - state.gap.x)
	content.content_size.y = max(content.content_size.y, state.cursor.y + state.line_height)

	return true
}

end_wrap :: proc() {
	container := &ctx.buffer[ctx.current_scope]
	parent_idx := container.parent

	end_scope()
	end_scope()

	if parent_idx != -1 {
		parent := &ctx.buffer[parent_idx]
		parent.cursor.y += container.size.y
	}
}

@(deferred_none = end_wrap)
wrap :: proc(size: Vec2, gap: Vec2 = {0, 0}, padding: [4]f32 = {0, 0, 0, 0}) -> Wrap {
	return begin_wrap(size, gap, padding)
}

