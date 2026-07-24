package ui

grid :: proc(
	offset: ^f64,
	container_size: Vec2,
	items_count: int,
	item_base_size: Vec2,
	gap: Vec2,
	ud: rawptr,
	item: proc(i: int, ud: rawptr),
	flags: Scope_Flags = {},
	item_flags: Scope_Flags = {},
) {
	scope(container_size, flags)
	container := get_scope()

	bind(.Scroll_Y, offset)

	aspect_ratio := item_base_size.x / item_base_size.y
	columns := max(int((container_size.x + gap.x) / (item_base_size.x + gap.x)), 1)

	cell_width := (container_size.x - f64(columns - 1) * gap.x) / f64(columns)
	cell_height := cell_width / aspect_ratio
	cell_size := Vec2{cell_width, cell_height}

	pitch_y := cell_height + gap.y
	rows_count := (items_count + columns - 1) / columns

	skip_rows := max(int(offset^ / pitch_y), 0)
	visible_rows := int(container_size.y / pitch_y) + 2

	container.cursor += {0, f64(skip_rows) * pitch_y}

	start_row := skip_rows
	end_row := min(skip_rows + visible_rows, rows_count)

	for r in start_row ..< end_row {
		for c in 0 ..< columns {
			item_idx := r * columns + c
			if item_idx >= items_count do break

			container.cursor.x = f64(c) * (cell_width + gap.x)

			scope(cell_size, item_flags)
			item(item_idx, ud)
		}

		container.cursor = {0, container.cursor.y + pitch_y}
	}

	container.content_size = {0, max(f64(rows_count) * pitch_y - gap.y, 0)}
}

Grid_State :: struct($T: typeid) {
	ud: T,
	fn: proc(i: int, ud: T),
}

grid_with_poly :: proc(
	offset: ^f64,
	container_size: Vec2,
	items_count: int,
	item_base_size: Vec2,
	gap: Vec2,
	ud: $T,
	item: proc(i: int, ud: T),
	flags: Scope_Flags = {},
	item_flags: Scope_Flags = {},
) {
	ptr := temp(Grid_State(T))
	ptr^ = Grid_State(T){ud, item}

	fn :: proc(i: int, ud: rawptr) {
		st := (^Grid_State(T))(ud)
		st.fn(i, st.ud)
	}

	grid(offset, container_size, items_count, item_base_size, gap, ptr, fn, flags, item_flags)
}

