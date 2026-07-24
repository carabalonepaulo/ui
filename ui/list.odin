package ui

list :: proc(
	uid: Id,
	size: Vec2,
	items_count: int,
	item_height: f64,
	gap: f64,
	ud: rawptr,
	item: proc(i: int, ud: rawptr),
) {
	scope(size, {.Clip})

	offset := get(id(uid, "offset"), f64)
	container := get_scope()
	bind(.Scroll_Y, offset)

	pitch := item_height + gap
	skip := max(int(offset^ / pitch), 0)
	visible := int(size.y / pitch) + 2
	container.cursor += {0, f64(skip) * pitch}

	for i in skip ..< min(skip + visible, items_count) {
		scope({size.x, item_height})
		item(i, ud)
		container.cursor += {0, pitch}
	}

	container.content_size = {0, max(f64(items_count) * pitch - gap, 0)}
}

List_State :: struct($T: typeid) {
	ud: T,
	fn: proc(i: int, ud: T),
}

list_with_poly :: proc(
	uid: Id,
	size: Vec2,
	items_count: int,
	item_height: f64,
	gap: f64,
	ud: $T,
	item: proc(i: int, ud: T),
) {
	ptr := temp(List_State(T))
	ptr^ = List_State(T){ud, item}

	list(uid, size, items_count, item_height, gap, ptr, proc(i: int, ud: rawptr) {
		ud := (^List_State(T))(ud)
		ud.fn(i, ud.ud)
	})
}

