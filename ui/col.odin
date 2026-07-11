package ui

Col :: struct {
	content_scope:    int,
	current_child:    int,
	computed_heights: []f32,
	gap:              f32,
}

begin_col :: proc(
	size: Vec2,
	items: []Layout_Item,
	gap: f32 = 0,
	padding: [4]f32 = {0, 0, 0, 0},
) -> Col {
	begin_scope(size)

	container := get_scope()
	container.cursor = {padding[3], padding[0]}

	usable_size := Vec2{size.x - (padding[1] + padding[3]), size.y - (padding[0] + padding[2])}

	begin_scope(usable_size)

	state := Col {
		content_scope    = ctx.current_scope,
		current_child    = 0,
		computed_heights = make([]f32, len(items), ctx.arena_allocator),
		gap              = gap,
	}

	total_gaps := f32(max(0, len(items) - 1)) * gap
	usable_height_for_items := usable_size.y - total_gaps

	total_absolute: f32 = 0
	total_flex: f32 = 0
	for item in items {
		if item.kind == .Absolute do total_absolute += item.value
		else do total_flex += item.value
	}

	remaining := usable_height_for_items - total_absolute

	for item, i in items {
		if item.kind == .Absolute {
			state.computed_heights[i] = item.value
		} else if total_flex > 0 {
			state.computed_heights[i] = (item.value / total_flex) * remaining
		}
	}

	return state
}

@(private = "file")
end_col_child :: proc(state: ^Col, success: bool) {
	if success do end_scope()
}

@(deferred_in_out = end_col_child)
col_next :: proc(state: ^Col) -> bool {
	if state.current_child >= len(state.computed_heights) {
		return false
	}

	content := &ctx.buffer[state.content_scope]
	width := content.size.x
	height := state.computed_heights[state.current_child]

	begin_scope({width, height})

	content.cursor.y += height
	if state.current_child < len(state.computed_heights) - 1 {
		content.cursor.y += state.gap
	}

	state.current_child += 1
	return true
}

end_col :: proc() {
	container := &ctx.buffer[ctx.current_scope]
	parent_idx := container.parent

	end_scope()
	end_scope()

	if parent_idx != -1 {
		parent := &ctx.buffer[parent_idx]
		parent.cursor.y += container.content_size.y
	}
}

@(deferred_none = end_col)
col :: proc(
	size: Vec2,
	items: []Layout_Item,
	gap: f32 = 0,
	padding: [4]f32 = {0, 0, 0, 0},
) -> Col {
	return begin_col(size, items, gap, padding)
}

