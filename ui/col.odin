package ui

AUTO :: -1

Col :: struct {
	container_scope:  int,
	content_scope:    int,
	current_child:    int,
	computed_heights: []f32,
	gap:              f32,
	padding:          [4]f32,
	fit:              Fit,
}

begin_col :: proc(
	uid: Id,
	size: Vec2,
	items: []Layout_Item,
	gap: f32 = 0,
	padding: [4]f32 = {0, 0, 0, 0},
) -> Col {
	fit := begin_fit(id(uid, "size"), size)

	container_scope := get_scope_id()
	container := get_scope()
	container.cursor = {padding[3], padding[0]}

	usable_size := Vec2{size.x - (padding[1] + padding[3]), size.y - (padding[0] + padding[2])}

	begin_scope(usable_size)

	state := Col {
		container_scope  = container_scope,
		content_scope    = ctx.current_scope,
		current_child    = 0,
		computed_heights = make([]f32, len(items), ctx.arena_allocator),
		gap              = gap,
		padding          = padding,
		fit              = fit,
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

end_col :: proc(col: Col) {
	container := &ctx.buffer[col.container_scope]
	content := &ctx.buffer[col.content_scope]
	parent_idx := container.parent

	end_scope()

	container.content_size = {
		content.content_size.x + col.padding[1] + col.padding[3],
		content.content_size.y + col.padding[0] + col.padding[2],
	}

	end_fit(col.fit)

	if parent_idx != -1 {
		parent := &ctx.buffer[parent_idx]
		parent.cursor.y += container.content_size.y
	}
}

@(deferred_out = end_col)
col :: proc(
	uid: Id,
	size: Vec2,
	items: []Layout_Item,
	gap: f32 = 0,
	padding: [4]f32 = {0, 0, 0, 0},
) -> Col {
	return begin_col(uid, size, items, gap, padding)
}

