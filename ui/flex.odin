package ui

Layout_Kind :: enum {
	Absolute,
	Flex,
}

Layout_Item :: struct {
	kind:  Layout_Kind,
	value: f32,
}

Flex :: struct {
	inner_flags:   Scope_Flags,
	dir:           Dir,
	current_child: int,
	computed:      []f32,
	gap:           f32,
}

begin_flex :: proc(
	size: Vec2,
	dir: Dir,
	items: []Layout_Item,
	gap: f32 = 0,
	flags: Scope_Flags = {},
	inner_flags: Scope_Flags = {},
) -> Flex {
	begin_scope(size, flags)

	container := get_scope()
	size := get_size()

	state := Flex {
		inner_flags   = inner_flags,
		dir           = dir,
		current_child = 0,
		computed      = make([]f32, len(items), ctx.arena_allocator),
		gap           = gap,
	}

	total_gaps := f32(max(0, len(items) - 1)) * gap
	usable_for_items := size[dir] - total_gaps

	total_absolute: f32 = 0
	total_flex: f32 = 0

	for item in items {
		if item.kind == .Absolute do total_absolute += item.value
		else do total_flex += item.value
	}

	remaining := usable_for_items - total_absolute

	for item, i in items {
		if item.kind == .Absolute {
			state.computed[i] = item.value
		} else if total_flex > 0 {
			state.computed[i] = (item.value / total_flex) * remaining
		}
	}

	return state
}

@(private = "file")
end_flex_child :: proc(state: ^Flex, success: bool) {
	if success do end_scope()
}

@(deferred_in_out = end_flex_child)
flex_next :: proc(state: ^Flex) -> bool {
	if state.current_child >= len(state.computed) {
		return false
	}

	container := get_scope()
	child_size := Vec2{0, 0}

	if state.dir == .X {
		child_size = {state.computed[state.current_child], container.size.y}
	} else {
		child_size = {container.size.x, state.computed[state.current_child]}
	}

	begin_scope(child_size, state.inner_flags)

	container.cursor[state.dir] += child_size[state.dir]
	if state.current_child < len(state.computed) - 1 {
		container.cursor[state.dir] += state.gap
	}

	state.current_child += 1

	return true
}

@(deferred_none = end_scope)
flex :: proc(
	size: Vec2,
	dir: Dir,
	items: []Layout_Item,
	gap: f32 = 0,
	flags: Scope_Flags = {},
	inner_flags: Scope_Flags = {},
) -> Flex {
	return begin_flex(size, dir, items, gap, flags, inner_flags)
}

