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
	container_scope: int,
	content_scope:   int,
	current_child:   int,
	computed_widths: []f32,
	gap:             f32,
	padding:         [4]f32,
	fit:             Maybe(Fit),
}

begin_row :: proc(
	uid: Id,
	size: Vec2,
	items: []Layout_Item,
	gap: f32 = 0,
	padding: [4]f32 = {0, 0, 0, 0},
) -> Row {
	fit: Maybe(Fit)
	if size.x == AUTO {
		fit = begin_fit(id(uid, "fit"), size)
	} else {
		begin_scope(size)
	}

	size := get_size()

	container_scope := get_scope_id()
	container := get_scope()
	container.cursor = {padding[3], padding[0]}

	usable_size := Vec2{size.x - (padding[1] + padding[3]), size.y - (padding[0] + padding[2])}

	begin_scope(usable_size)

	state := Row {
		container_scope = container_scope,
		content_scope   = ctx.current_scope,
		current_child   = 0,
		computed_widths = make([]f32, len(items), ctx.arena_allocator),
		gap             = gap,
		padding         = padding,
		fit             = fit,
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

end_row :: proc(row: Row) {
	container := &ctx.buffer[row.container_scope]
	content := &ctx.buffer[row.content_scope]
	parent_idx := container.parent

	end_scope()

	container.content_size = {
		content.content_size.x + row.padding[1] + row.padding[3],
		content.content_size.y + row.padding[0] + row.padding[2],
	}

	if fit, ok := row.fit.(Fit); ok {
		end_fit(fit)
	} else {
		end_scope()
	}

	if parent_idx != -1 {
		parent := &ctx.buffer[parent_idx]
		parent.cursor.x += container.content_size.x
	}
}

@(deferred_out = end_row)
row :: proc(
	uid: Id,
	size: Vec2,
	items: []Layout_Item,
	gap: f32 = 0,
	padding: [4]f32 = {0, 0, 0, 0},
) -> Row {
	return begin_row(uid, size, items, gap, padding)
}

