package ui

Wrap :: struct {
	container_scope: int,
	content_scope:   int,
	cursor:          Vec2,
	line_height:     f64,
	usable_size:     Vec2,
	gap:             Vec2,
	padding:         [4]f64,
}

begin_wrap :: proc(
	uid: Id,
	size: Vec2,
	gap: Vec2 = {0, 0},
	padding: [4]f64 = {0, 0, 0, 0},
) -> Wrap {
	begin_scope(size)

	container_scope := get_scope_id()
	container := get_scope()
	container.cursor = {padding[3], padding[0]}

	usable_size := Vec2{size.x - (padding[1] + padding[3]), size.y - (padding[0] + padding[2])}

	begin_scope(usable_size, {.Clip})

	return Wrap {
		container_scope = container_scope,
		content_scope = ctx.current_scope,
		cursor = {},
		line_height = 0,
		usable_size = usable_size,
		gap = gap,
		padding = padding,
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

end_wrap :: proc(wrap: Wrap) {
	container := &ctx.buffer[wrap.container_scope]
	content := &ctx.buffer[wrap.content_scope]
	parent_idx := container.parent

	end_scope()

	container.content_size = {
		content.content_size.x + wrap.padding[1] + wrap.padding[3],
		content.content_size.y + wrap.padding[0] + wrap.padding[2],
	}

	end_scope()

	if parent_idx != -1 {
		parent := &ctx.buffer[parent_idx]
		parent.cursor.y += container.size.y
	}
}

@(deferred_out = end_wrap)
wrap :: proc(uid: Id, size: Vec2, gap: Vec2 = {0, 0}, padding: [4]f64 = {0, 0, 0, 0}) -> Wrap {
	return begin_wrap(uid, size, gap, padding)
}

