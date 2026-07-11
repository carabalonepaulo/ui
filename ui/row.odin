package ui

Layout_Kind :: enum {
	Absolute,
	Flex,
}

Layout_Item :: struct {
	kind:  Layout_Kind,
	value: f32,
}

Row :: struct {
	content_scope:   int,
	current_child:   int,
	computed_widths: []f32,
	gap:             f32,
}

begin_row :: proc(
	size: Vec2,
	items: []Layout_Item,
	gap: f32 = 0,
	padding: [4]f32 = {0, 0, 0, 0},
) -> Row {
	begin_scope(size)

	container := get_scope()
	container.cursor = {padding[3], padding[0]}

	usable_size := Vec2{size.x - (padding[1] + padding[3]), size.y - (padding[0] + padding[2])}

	begin_scope(usable_size)

	state := Row {
		content_scope   = ctx.current_scope,
		current_child   = 0,
		computed_widths = make([]f32, len(items), ctx.arena_allocator),
		gap             = gap,
	}

	total_gaps := f32(max(0, len(items) - 1)) * gap
	usable_width_for_items := usable_size.x - total_gaps

	total_absolute: f32 = 0
	total_flex: f32 = 0
	for item in items {
		if item.kind == .Absolute do total_absolute += item.value
		else do total_flex += item.value
	}

	remaining := usable_width_for_items - total_absolute

	for item, i in items {
		if item.kind == .Absolute {
			state.computed_widths[i] = item.value
		} else if total_flex > 0 {
			state.computed_widths[i] = (item.value / total_flex) * remaining
		}
	}

	return state
}

@(private = "file")
end_row_child :: proc(state: ^Row, success: bool) {
	if success do end_scope()
}

@(deferred_in_out = end_row_child)
row_next :: proc(state: ^Row) -> bool {
	if state.current_child >= len(state.computed_widths) {
		return false
	}

	content := &ctx.buffer[state.content_scope]
	width := state.computed_widths[state.current_child]
	height := content.size.y

	begin_scope({width, height})

	content.cursor.x += width
	if state.current_child < len(state.computed_widths) - 1 {
		content.cursor.x += state.gap
	}

	state.current_child += 1

	return true
}

end_row :: proc() {
	container := &ctx.buffer[ctx.current_scope]
	parent_idx := container.parent

	end_scope()
	end_scope()

	if parent_idx != -1 {
		parent := &ctx.buffer[parent_idx]
		parent.cursor.x += container.content_size.x
	}
}

@(deferred_none = end_row)
row :: proc(
	size: Vec2,
	items: []Layout_Item,
	gap: f32 = 0,
	padding: [4]f32 = {0, 0, 0, 0},
) -> Row {
	return begin_row(size, items, gap, padding)
}

